pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'DOCKER_IMAGE', defaultValue: 'your-dockerhub-username/dynamic-site', description: 'Docker Hub image name')
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region for Terraform')
        string(name: 'YOUR_IP_CIDR', defaultValue: '0.0.0.0/0', description: 'Your public IP in CIDR format, for example 49.36.55.12/32')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Force Terraform apply even if terraform files did not change')
    }

    environment {
        CONTAINER_NAME = 'dynamic-site'
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
                sh '''
                    docker build -t "$FULL_IMAGE" -t "$LATEST_IMAGE" .
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'DOCKERHUB_CREDENTIALS', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push "$FULL_IMAGE"
                        docker push "$LATEST_IMAGE"
                    '''
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
                    string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    dir('terraform') {
                        sh '''
                            terraform init
                            terraform apply -auto-approve \
                              -var="aws_region=$AWS_REGION" \
                              -var="your_ip=$YOUR_IP_CIDR"
                        '''
                        script {
                            env.DEPLOY_HOST = sh(script: 'terraform output -raw ec2_public_ip', returnStdout: true).trim()
                        }
                    }
                }
            }
        }

        stage('Deploy Website to EC2') {
            steps {
                script {
                    if (!env.DEPLOY_HOST?.trim()) {
                        withCredentials([string(credentialsId: 'EC2_HOST', variable: 'CREDENTIAL_EC2_HOST')]) {
                            env.DEPLOY_HOST = env.CREDENTIAL_EC2_HOST
                        }
                    }
                }
                withCredentials([
                    string(credentialsId: 'EC2_USER', variable: 'EC2_USER'),
                    sshUserPrivateKey(credentialsId: 'EC2_SSH_KEY', keyFileVariable: 'EC2_KEY')
                ]) {
                    sh '''
                        ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$DEPLOY_HOST" "
                          docker pull '$FULL_IMAGE' &&
                          (docker stop '$CONTAINER_NAME' || true) &&
                          (docker rm '$CONTAINER_NAME' || true) &&
                          docker run -d --restart unless-stopped --name '$CONTAINER_NAME' -p 80:80 '$FULL_IMAGE' &&
                          docker ps --filter name='$CONTAINER_NAME'
                        "
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Build, push, and deployment completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check the stage logs above.'
        }
    }
}
