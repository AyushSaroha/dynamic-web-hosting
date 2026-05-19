pipeline {
    agent any

    environment {
        IMAGE_NAME = "dynamic-site"
        CONTAINER_NAME = "dynamic-site-container"
    }

    stages {

        stage('Clone Code') {
            steps {
                git branch: 'main',
                url: 'https://github.com/AyushSaroha/dynamic-web-hosting.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat "docker build -t %IMAGE_NAME% ."
            }
        }

        stage('Stop Old Container') {
            steps {
                bat '''
                docker stop %CONTAINER_NAME% || exit 0
                docker rm %CONTAINER_NAME% || exit 0
                '''
            }
        }

        stage('Run New Container') {
            steps {
                bat '''
                docker run -d ^
                --name %CONTAINER_NAME% ^
                -p 8081:80 ^
                %IMAGE_NAME%
                '''
            }
        }

        stage('Verify Running Container') {
            steps {
                bat "docker ps"
            }
        }
    }

    post {
        success {
            echo 'Docker container deployed successfully!'
        }

        failure {
            echo 'Deployment failed!'
        }
    }
}
