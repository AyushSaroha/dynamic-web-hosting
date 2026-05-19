pipeline {
    agent any

    stages {
        stage('Clone Code') {
            steps {
                git url: 'https://github.com/AyushSaroha/dynamic-web-hosting.git', branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t dynamic-site .'
            }
        }

        stage('Stop Old Container') {
            steps {
                // exit 0 ensures Windows always reports a success even if no container exists
                bat 'docker stop dynamic-site 2>nul || exit 0'
                bat 'docker rm dynamic-site 2>nul || exit 0'
            }
        }

        stage('Run New Container') {
            steps {
                bat 'docker run -d --name dynamic-site -p 8081:80 dynamic-site'
            }
        }
    }
}
