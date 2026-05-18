pipeline {
    agent any

    stages {

        stage('Clone Code') {
            steps {
                git 'YOUR_GITHUB_REPO_LINK'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t dynamic-site .'
            }
        }

        stage('Stop Old Container') {
            steps {
                sh 'docker stop dynamic-site || true'
                sh 'docker rm dynamic-site || true'
            }
        }

        stage('Run New Container') {
            steps {
                sh 'docker run -d --name dynamic-site -p 80:80 dynamic-site'
            }
        }
    }
}

