pipeline {
    agent any
    
    environment {
        PYTHON_VERSION = '3.11'
        VENV_DIR = 'venv'
        APP_DIR = 'sample-app'
        DEPLOY_USER = 'jenkins'
        DEPLOY_HOST = credentials('deploy-host')
        DEPLOY_PATH = '/opt/python-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup Python Environment') {
            steps {
                dir("${APP_DIR}") {
                    sh '''
                        python3 -m venv ${VENV_DIR}
                        . ${VENV_DIR}/bin/activate
                        pip install --upgrade pip
                        pip install -r requirements.txt
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                dir("${APP_DIR}") {
                    sh '''
                        . ${VENV_DIR}/bin/activate
                        pytest -v test_app.py
                    '''
                }
            }
        }
        
        stage('Build Artifact') {
            steps {
                dir("${APP_DIR}") {
                    sh '''
                        tar czf ../python-app-${BUILD_NUMBER}.tar.gz \
                            --exclude=${VENV_DIR} \
                            --exclude=__pycache__ \
                            --exclude=*.pyc \
                            .
                    '''
                }
                archiveArtifacts artifacts: 'python-app-*.tar.gz', fingerprint: true
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh """
                        scp python-app-${BUILD_NUMBER}.tar.gz ${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/
                        ssh ${DEPLOY_USER}@${DEPLOY_HOST} '
                            sudo mkdir -p ${DEPLOY_PATH}
                            sudo tar xzf /tmp/python-app-${BUILD_NUMBER}.tar.gz -C ${DEPLOY_PATH}
                            cd ${DEPLOY_PATH}
                            python3 -m venv venv
                            . venv/bin/activate
                            pip install -r requirements.txt
                            sudo systemctl restart python-app
                        '
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check logs for details.'
        }
        always {
            cleanWs()
        }
    }
}
