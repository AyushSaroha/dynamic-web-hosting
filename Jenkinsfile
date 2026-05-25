pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    triggers {
        githubPush()
    }

    parameters {

        string(
            name: 'DOCKER_IMAGE',
            defaultValue: 'ayushsaroha8791/dynamic-site',
            description: 'Docker Hub image name'
        )

        string(
            name: 'AWS_REGION',
            defaultValue: 'us-east-2',
            description: 'AWS Region'
        )

        string(
            name: 'YOUR_IP_CIDR',
            defaultValue: '',
            description: 'Optional SSH allowed IP in CIDR. Leave blank to auto-detect Jenkins public IP.'
        )

        booleanParam(
            name: 'APPLY_TERRAFORM',
            defaultValue: true,
            description: 'Run Terraform Apply'
        )
    }

    environment {
        CONTAINER_NAME = 'dynamic-site-container'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        TF_IN_AUTOMATION = 'true'
    }

    stages {

        // ─────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ─────────────────────────────────────────
        stage('Build Docker Image') {
            steps {
                script {
                    env.FULL_IMAGE   = "${params.DOCKER_IMAGE}:${env.IMAGE_TAG}"
                    env.LATEST_IMAGE = "${params.DOCKER_IMAGE}:latest"
                }
                bat """
                docker build -t %FULL_IMAGE% -t %LATEST_IMAGE% .
                """
            }
        }

        // ─────────────────────────────────────────
        stage('Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'DOCKERHUB_CREDENTIALS',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat """
                    echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                    docker push %FULL_IMAGE%
                    docker push %LATEST_IMAGE%
                    """
                }
            }
        }

        // ─────────────────────────────────────────
        // FIX 1: Use sshUserPrivateKey (not file) because EC2_KEY is stored
        //        as "SSH Username with private key" in Jenkins credentials.
        //        keyFileVariable gives you the path to a temp key file — same
        //        as what file() would have given, so ssh -i %KEY_FILE% still works.
        // ─────────────────────────────────────────
        stage('Terraform Apply') {
            when {
                anyOf {
                    expression { return params.APPLY_TERRAFORM }
                    changeset 'terraform/**'
                    changeset 'monitoring/**'
                }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY'),

                    // ✅ FIXED: was file(...) — must be sshUserPrivateKey for
                    //           "SSH Username with private key" credential type
                    sshUserPrivateKey(
                        credentialsId:  'EC2_KEY',
                        keyFileVariable: 'KEY_FILE',   // path to temp private-key file
                        usernameVariable: 'SSH_USER'   // usually 'ubuntu' — captured but optional here
                    )
                ]) {
                    dir('terraform') {
                        bat """
                        set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                        set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%

                        if not exist keys mkdir keys
                        ssh-keygen -y -f "%KEY_FILE%" > keys\\dynamic-site-key.pub

                        set "TF_SSH_CIDR=%YOUR_IP_CIDR%"
                        if "%TF_SSH_CIDR%"=="" (
                          for /f "usebackq delims=" %%I in (`curl -s https://checkip.amazonaws.com`) do set "TF_SSH_CIDR=%%I/32"
                        )
                        echo Allowing SSH from %TF_SSH_CIDR%

                        terraform init

                        terraform apply -auto-approve ^
                          -var="aws_region=%AWS_REGION%" ^
                          -var="your_ip=%TF_SSH_CIDR%" ^
                          -var="docker_image=%LATEST_IMAGE%" ^
                          -var="public_key_path=%CD%\\dynamic-site-key.pub"
                        """

                        script {
                            env.EC2_IP = bat(
                                script: '@terraform output -raw ec2_public_ip',
                                returnStdout: true
                            ).trim().replaceAll("[\\r\\n]", "")

                            echo "EC2 Public IP (from Terraform Apply): ${env.EC2_IP}"
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────
        // FIX 2: EC2_IP — fetch dynamically from terraform output when
        //        Terraform Apply stage was skipped (APPLY_TERRAFORM=false).
        //        Also use sshUserPrivateKey here for the same reason.
        //
        // FIX 3: Replaced hardcoded IP (18.190.184.38) with ${env.EC2_IP}
        // ─────────────────────────────────────────
        stage('Deploy Website to EC2') {
            steps {
                script {

                    // If Terraform Apply was skipped, EC2_IP is not yet set.
                    // Fetch it from the existing terraform state.
                    if (!env.EC2_IP) {
                        dir('terraform') {
                            env.EC2_IP = bat(
                                script: '@terraform output -raw ec2_public_ip',
                                returnStdout: true
                            ).trim().replaceAll("[\\r\\n]", "")
                        }
                    }

                    echo "Deploying to EC2 IP: ${env.EC2_IP}"

                    // ✅ FIXED: was file(...) — must match credential type
                    withCredentials([
                        sshUserPrivateKey(
                            credentialsId:   'EC2_KEY',
                            keyFileVariable: 'KEY_FILE',
                            usernameVariable: 'SSH_USER'
                        )
                    ]) {
                        env.SAFE_KEY_FILE = "${env.WORKSPACE}\\ec2-key-${env.BUILD_NUMBER}.pem"

                        bat """
                        copy /Y "%KEY_FILE%" "%SAFE_KEY_FILE%" >NUL
                        icacls "%SAFE_KEY_FILE%" /inheritance:r
                        icacls "%SAFE_KEY_FILE%" /grant:r "%USERNAME%:R"
                        icacls "%SAFE_KEY_FILE%" /remove:g "BUILTIN\\Users" 2>NUL || ver >NUL
                        icacls "%SAFE_KEY_FILE%" /remove:g "NT AUTHORITY\\Authenticated Users" 2>NUL || ver >NUL
                        icacls "%SAFE_KEY_FILE%" /remove:g "Everyone" 2>NUL || ver >NUL
                        """

                        // Wait until EC2 instance is fully ready
                        timeout(time: 6, unit: 'MINUTES') {
                            waitUntil {
                                def readyStatus = bat(
                                    script: """@ssh -i "%SAFE_KEY_FILE%" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${env.EC2_IP} "cloud-init status --wait && sudo systemctl is-active --quiet docker" """,
                                    returnStatus: true
                                )
                                if (readyStatus != 0) {
                                    sleep time: 10, unit: 'SECONDS'
                                    return false
                                }
                                return true
                            }
                        }

                        // ✅ FIX 3: use ${env.EC2_IP} — NOT the hardcoded IP
                        bat """
                        ssh -i "%SAFE_KEY_FILE%" -o StrictHostKeyChecking=no ubuntu@${env.EC2_IP} ^
                        "sudo docker stop %CONTAINER_NAME% || true && ^
                        sudo docker rm   %CONTAINER_NAME% || true && ^
                        sudo docker pull %LATEST_IMAGE%          && ^
                        sudo docker run -d --restart unless-stopped ^
                          --name %CONTAINER_NAME% -p 80:80 ^
                          %LATEST_IMAGE%                         && ^
                        sudo docker ps"
                        """
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    post {

        success {
            echo 'Build, Push, Terraform, and Deployment completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check Jenkins logs.'
        }

        always {
            cleanWs(
                deleteDirs: false,
                notFailBuild: true,
                patterns: [
                    [pattern: 'terraform/terraform.tfstate',        type: 'EXCLUDE'],
                    [pattern: 'terraform/terraform.tfstate.backup', type: 'EXCLUDE']
                ]
            )
        }
    }
}
