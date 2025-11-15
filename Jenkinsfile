pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'prod'],
            description: 'Target environment for deployment'
        )
        string(
            name: 'VERSION',
            defaultValue: 'latest',
            description: 'Docker image version tag'
        )
    }

    environment {
        PROJECT_NAME = 'payloadapi'
        REGISTRY = credentials('docker-registry-url')  // Configure in Jenkins credentials
        KUBECONFIG = credentials("kubeconfig-${params.ENVIRONMENT}")  // Configure in Jenkins credentials
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Decrypt Secrets') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'ansible-vault-password', variable: 'VAULT_PASS_FILE')]) {
                        sh """
                            ansible-vault decrypt \
                                secrets/${params.ENVIRONMENT}.yml \
                                --vault-password-file=\$VAULT_PASS_FILE \
                                --output=secrets/${params.ENVIRONMENT}.decrypted.yml
                        """
                    }
                }
            }
        }

        stage('Extract Configuration') {
            steps {
                script {
                    env.CONNECTION_STRING = sh(
                        script: "grep '^connection_string:' secrets/${params.ENVIRONMENT}.decrypted.yml | sed 's/^connection_string: *\"\\(.*\\)\"/\\1/'",
                        returnStdout: true
                    ).trim()

                    env.NAMESPACE = sh(
                        script: "grep '^namespace:' secrets/${params.ENVIRONMENT}.decrypted.yml | awk '{print \$2}'",
                        returnStdout: true
                    ).trim()

                    echo "Deploying to namespace: ${env.NAMESPACE}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('app/PayloadApi') {
                    script {
                        sh """
                            docker build -t ${PROJECT_NAME}:${params.VERSION} .
                            docker tag ${PROJECT_NAME}:${params.VERSION} ${REGISTRY}/${PROJECT_NAME}:${params.VERSION}
                            docker tag ${PROJECT_NAME}:${params.VERSION} ${REGISTRY}/${PROJECT_NAME}:${params.ENVIRONMENT}-latest
                        """
                    }
                }
            }
        }

        stage('Push to Registry') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-registry-credentials', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                        sh """
                            echo \$DOCKER_PASS | docker login ${REGISTRY} -u \$DOCKER_USER --password-stdin
                            docker push ${REGISTRY}/${PROJECT_NAME}:${params.VERSION}
                            docker push ${REGISTRY}/${PROJECT_NAME}:${params.ENVIRONMENT}-latest
                        """
                    }
                }
            }
        }

        stage('Create K8s Secret Manifest') {
            steps {
                script {
                    sh """
                        sed "s|CONNECTION_STRING_PLACEHOLDER|${env.CONNECTION_STRING}|g" \
                            k8s/${params.ENVIRONMENT}/secret.yml.template > k8s/${params.ENVIRONMENT}/secret.yml
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    sh """
                        kubectl apply -f k8s/${params.ENVIRONMENT}/namespace.yml
                        kubectl apply -f k8s/${params.ENVIRONMENT}/serviceaccount.yml
                        kubectl apply -f k8s/${params.ENVIRONMENT}/configmap.yml
                        kubectl apply -f k8s/${params.ENVIRONMENT}/secret.yml
                        kubectl apply -f k8s/${params.ENVIRONMENT}/deployment.yml
                        kubectl apply -f k8s/${params.ENVIRONMENT}/service.yml
                        kubectl apply -f k8s/${params.ENVIRONMENT}/ingress.yml
                    """
                }
            }
        }

        stage('Wait for Deployment') {
            steps {
                script {
                    sh """
                        kubectl wait --for=condition=available --timeout=300s \
                            deployment/${PROJECT_NAME} -n ${env.NAMESPACE}
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                        kubectl get all,ingress -n ${env.NAMESPACE}
                        kubectl get pods -n ${env.NAMESPACE}
                    """
                }
            }
        }
    }

    post {
        always {
            // Clean up decrypted secrets
            sh """
                rm -f secrets/${params.ENVIRONMENT}.decrypted.yml
                rm -f k8s/${params.ENVIRONMENT}/secret.yml
            """
        }
        success {
            echo "✓ Deployment to ${params.ENVIRONMENT} completed successfully!"
            echo "Namespace: ${env.NAMESPACE}"
        }
        failure {
            echo "✗ Deployment to ${params.ENVIRONMENT} failed!"
        }
    }
}
