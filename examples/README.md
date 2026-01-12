# Jenkins Lab Examples

Additional examples and templates for extending the Jenkins lab.

## Contents

- [terraform-vars.example.tfvars](#terraform-variables)
- [multi-branch-pipeline.jenkinsfile](#multi-branch-pipeline)
- [docker-compose.yml](#docker-compose)

## Terraform Variables

Example variable files for each cloud provider.

### AWS

```hcl
# terraform/aws/terraform.tfvars
region          = "us-west-2"
instance_type   = "t3.large"
key_name        = "my-jenkins-key"
public_key_path = "~/.ssh/jenkins_rsa.pub"
vpc_cidr        = "10.100.0.0/16"
```

### Azure

```hcl
# terraform/azure/terraform.tfvars
location       = "westus2"
admin_username = "jenkins"
ssh_public_key = "~/.ssh/jenkins_rsa.pub"
vm_size        = "Standard_D2s_v3"
```

### GCP

```hcl
# terraform/gcp/terraform.tfvars
project      = "my-gcp-project-123"
region       = "us-west1"
zone         = "us-west1-a"
machine_type = "e2-standard-2"
```

## Multi-Branch Pipeline

Example Jenkinsfile for multi-branch projects:

```groovy
// examples/multi-branch-pipeline.jenkinsfile
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'myapp'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME
                    def imageTag = "${branchName}-${env.BUILD_NUMBER}"
                    
                    sh """
                        docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${imageTag} .
                        docker tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${imageTag} \
                                   ${DOCKER_REGISTRY}/${IMAGE_NAME}:${branchName}-latest
                    """
                }
            }
        }
        
        stage('Test') {
            steps {
                sh 'pytest tests/ -v --junitxml=reports/junit.xml'
            }
            post {
                always {
                    junit 'reports/junit.xml'
                }
            }
        }
        
        stage('Deploy') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    def env = (env.BRANCH_NAME == 'main') ? 'production' : 'staging'
                    sh """
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${env.BRANCH_NAME}-latest
                        kubectl set image deployment/myapp \
                            myapp=${DOCKER_REGISTRY}/${IMAGE_NAME}:${env.BRANCH_NAME}-latest \
                            -n ${env}
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        failure {
            emailext(
                subject: "Build Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Check console output at ${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
    }
}
```

## Docker Compose

Run Jenkins and agents with Docker Compose:

```yaml
# examples/docker-compose.yml
version: '3.8'

services:
  jenkins-controller:
    image: jenkins/jenkins:lts
    container_name: jenkins
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - ./casc:/var/jenkins_home/casc
    environment:
      - CASC_JENKINS_CONFIG=/var/jenkins_home/casc/jenkins.yaml
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    networks:
      - jenkins

  jenkins-agent:
    image: jenkins/inbound-agent:latest
    container_name: jenkins-agent-1
    environment:
      - JENKINS_URL=http://jenkins-controller:8080
      - JENKINS_SECRET=${JENKINS_AGENT_SECRET}
      - JENKINS_AGENT_NAME=agent-1
      - JENKINS_AGENT_WORKDIR=/home/jenkins/agent
    volumes:
      - agent_workdir:/home/jenkins/agent
    networks:
      - jenkins
    depends_on:
      - jenkins-controller

volumes:
  jenkins_home:
  agent_workdir:

networks:
  jenkins:
    driver: bridge
```

**Usage:**
```bash
# Set agent secret (get from Jenkins UI: Manage Jenkins → Nodes)
export JENKINS_AGENT_SECRET=your-secret-here

# Start services
docker-compose up -d

# View logs
docker-compose logs -f jenkins-controller

# Stop services
docker-compose down
```

## JCasC Examples

### Complete Configuration

```yaml
# examples/jenkins-complete.yaml
jenkins:
  systemMessage: "Jenkins configured automatically by JCasC"
  numExecutors: 0
  
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${JENKINS_ADMIN_PASSWORD}"
          
  authorizationStrategy:
    globalMatrix:
      permissions:
        - "Overall/Administer:admin"
        - "Overall/Read:authenticated"
        
  clouds:
    - docker:
        name: "docker"
        dockerApi:
          dockerHost:
            uri: "unix:///var/run/docker.sock"
        templates:
          - labelString: "docker-agent"
            dockerTemplateBase:
              image: "jenkins/inbound-agent:latest"
            remoteFs: "/home/jenkins/agent"
            connector:
              attach:
                user: "jenkins"
                
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: "github-credentials"
              username: "${GITHUB_USERNAME}"
              password: "${GITHUB_TOKEN}"
              description: "GitHub Access Token"
              
          - string:
              scope: GLOBAL
              id: "slack-token"
              secret: "${SLACK_TOKEN}"
              description: "Slack Notification Token"
              
jobs:
  - script: >
      multibranchPipelineJob('sample-app') {
        branchSources {
          git {
            remote('https://github.com/yourorg/sample-app.git')
            credentialsId('github-credentials')
          }
        }
      }
      
unclassified:
  location:
    url: "https://jenkins.example.com"
    adminAddress: "jenkins@example.com"
    
  globalLibraries:
    libraries:
      - name: "shared-library"
        retriever:
          modernSCM:
            scm:
              git:
                remote: "https://github.com/yourorg/jenkins-shared-library.git"
                credentialsId: "github-credentials"
```

## Shared Library Example

```groovy
// examples/shared-library/vars/deployApp.groovy
def call(Map config) {
    pipeline {
        agent any
        stages {
            stage('Deploy') {
                steps {
                    script {
                        sh """
                            scp -r ${config.artifactPath} ${config.targetHost}:${config.deployPath}
                            ssh ${config.targetHost} 'systemctl restart ${config.serviceName}'
                        """
                    }
                }
            }
        }
    }
}

// Usage in Jenkinsfile:
// @Library('shared-library') _
// deployApp(
//     artifactPath: 'dist/',
//     targetHost: 'production.example.com',
//     deployPath: '/opt/myapp',
//     serviceName: 'myapp'
// )
```

## Kubernetes Agent

```yaml
# examples/kubernetes-agent.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args:
      - "$(JENKINS_SECRET)"
      - "$(JENKINS_NAME)"
    env:
      - name: JENKINS_URL
        value: "http://jenkins.default.svc.cluster.local:8080"
  - name: docker
    image: docker:dind
    securityContext:
      privileged: true
    volumeMounts:
      - name: docker-sock
        mountPath: /var/run
  volumes:
    - name: docker-sock
      emptyDir: {}
```
