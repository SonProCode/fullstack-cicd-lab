pipeline {
    agent any

    environment {
        REGISTRY = "thson20210744"
        BACKEND_IMAGE = "fullstack-backend"
        FRONTEND_IMAGE = "fullstack-frontend"
        ONLY_BRANCH = "${env.GIT_BRANCH.split('/')[-1] == 'main' ? 'prod' : env.GIT_BRANCH.split('/')[-1]}"
        TAG = "${ONLY_BRANCH}-${env.BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Backend Image') {
            steps {
                sh '''
                    docker build \
                        -t $REGISTRY/$BACKEND_IMAGE:$TAG \
                        ./WebAPI/WebAPI
                '''
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                    docker build \
                        -t $REGISTRY/$FRONTEND_IMAGE:$TAG \
                        ./react-app
                '''
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
                }
            }
        }

        stage('Push Images') {
            steps {
                sh '''
                    docker push $REGISTRY/$BACKEND_IMAGE:$TAG
                    docker push $REGISTRY/$FRONTEND_IMAGE:$TAG
                '''
            }
        }
        
        stage('Update Terraform Manifest') {
            when {
                anyOf {
                  expression { env.ONLY_BRANCH == 'dev' }
                  expression { env.ONLY_BRANCH == 'uat' }
                  expression { env.ONLY_BRANCH == 'prod' }
                }
            }
            steps {
                sh '''
                    echo "Updating image tags in ./infras/$ONLY_BRANCH/terraform.yaml"
                    
                    # Đường dẫn tới file yaml theo cấu trúc thư mục của bạn
                    TARGET_FILE="./infras/$ONLY_BRANCH/terraform.yaml"

                    # Cập nhật tag cho Backend Image
                    sed -i "s|image: \\"$REGISTRY/$BACKEND_IMAGE:.*\\"|image: \\"$REGISTRY/$BACKEND_IMAGE:$TAG\\"|g" $TARGET_FILE

                    # Cập nhật tag cho Frontend Image
                    sed -i "s|image: \\"$REGISTRY/$FRONTEND_IMAGE:.*\\"|image: \\"$REGISTRY/$FRONTEND_IMAGE:$TAG\\"|g" $TARGET_FILE
                    
                    echo "New Backend Image: $REGISTRY/$BACKEND_IMAGE:$TAG"
                    echo "New Frontend Image: $REGISTRY/$FRONTEND_IMAGE:$TAG"
                '''
            }
        }

        stage('Deploy with Terraform') {
            when {
                anyOf {
                  expression { env.ONLY_BRANCH == 'dev' }
                  expression { env.ONLY_BRANCH == 'uat' }
                  expression { env.ONLY_BRANCH == 'prod' }
                }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh '''
                        cd infras

                        rm -rf .terraform .terraform.lock.hcl

                        terraform init -reconfigure \
                            -backend-config="bucket=sonth40-s3-tfstate-v2" \
                            -backend-config="key=fullstack/$ONLY_BRANCH/terraform.tfstate" \
                            -backend-config="region=ap-southeast-1"

                        terraform apply -target='module.acm["alb_cert"]' -auto-approve \
                            -var="environment=$ONLY_BRANCH"

                        terraform apply -auto-approve \
                            -var="environment=$ONLY_BRANCH"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "CI/CD SUCCESS – Deployed to environment: $ONLY_BRANCH (tag: $TAG)"
        }
        failure {
            echo "PIPELINE FAILED"
        }
    }
}
