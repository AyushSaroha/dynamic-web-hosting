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
            defaultValue: '117.251.86.153/32',
            description: 'Your Public IP in CIDR'
        )

        booleanParam(
            name: 'APPLY_TERRAFORM',
            defaultValue: true,
            description: 'Run Terraform Apply'
        )
    }

    environment {

        CONTAINER_NAME = 'dynamic-site-container'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        TF_IN_AUTOMATION = 'true'
    }

    stages {

        stage('Checkout') {

            steps {

                checkout scm
            }
        }

        stage('Build Docker Image') {

            steps {

                script {

                    env.FULL_IMAGE = "${params.DOCKER_IMAGE}:${env.IMAGE_TAG}"
                    env.LATEST_IMAGE = "${params.DOCKER_IMAGE}:latest"
                }

                bat """
                docker build -t %FULL_IMAGE% -t %LATEST_IMAGE% .
                """
            }
        }

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

                    string(
                        credentialsId: 'AWS_ACCESS_KEY_ID',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),

                    string(
                        credentialsId: 'AWS_SECRET_ACCESS_KEY',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    )

                ]) {

                    dir('terraform') {

                        bat """
                        set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                        set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%

                        terraform init

                        terraform apply -auto-approve ^
                          -var="aws_region=%AWS_REGION%" ^
                          -var="your_ip=%YOUR_IP_CIDR%"
                        """

                        script {

                            env.DEPLOY_HOST = bat(
                                script: '@terraform output -raw ec2_public_ip',
                                returnStdout: true
                            ).trim().replaceAll("[\\r\\n]", "")

                            echo "EC2 Public IP: ${env.DEPLOY_HOST}"
                        }
                    }
                }
            }
        }

        stage('Deploy Website to EC2') {

            steps {

                script {

                    dir('terraform') {

                        env.EC2_IP = bat(
                            script: '@terraform output -raw ec2_public_ip',
                            returnStdout: true
                        ).trim().replaceAll("[\\r\\n]", "")
                    }

                    echo "Deploying to ${env.EC2_IP}"

                    withCredentials([

                        file(
                            credentialsId: 'EC2_KEY',
                            variable: 'KEY_FILE'
                        )

                    ]) {

                        timeout(time: 6, unit: 'MINUTES') {
                            waitUntil {
                                def readyStatus = bat(
                                    script: """@ssh -i "%KEY_FILE%" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${env.EC2_IP} "cloud-init status --wait && sudo systemctl is-active --quiet docker" """,
                                    returnStatus: true
                                )

                                if (readyStatus != 0) {
                                    sleep time: 10, unit: 'SECONDS'
                                    return false
                                }

                                return true
                            }
                        }

                        bat """
                        ssh -i "%KEY_FILE%" -o StrictHostKeyChecking=no ubuntu@%EC2_IP% ^
                        "sudo docker stop %CONTAINER_NAME% || true && ^
                        sudo docker rm %CONTAINER_NAME% || true && ^
                        sudo docker pull %LATEST_IMAGE% && ^
                        sudo docker run -d --restart unless-stopped ^
                        --name %CONTAINER_NAME% -p 80:80 ^
                        %LATEST_IMAGE% && ^
                        sudo docker ps"
                        """
                    }
                }
            }
        }
    }

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
                    [pattern: 'terraform/terraform.tfstate', type: 'EXCLUDE'],
                    [pattern: 'terraform/terraform.tfstate.backup', type: 'EXCLUDE']
                ]
            )
        }
    }
}
