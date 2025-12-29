pipeline {
  agent any

  environment {
    REGISTRY = "thson20210744"
    BACKEND_IMAGE = "fullstack-backend"
    FRONTEND_IMAGE = "fullstack-frontend"
    
    ONLY_BRANCH = "${env.GIT_BRANCH.split('/')[-1]}"
    
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
  }
  stage('Deploy with Terraform') {
      when {
        anyOf {
          branch 'dev'
          branch 'uat'
          branch 'prod'
        }
      }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'aws-creds'
        ]]) {
          sh '''
            cd infras

              terraform init \
              -backend-config="bucket=sonth40-s3-tfstate-v2" \
              -backend-config="key=fullstack/$ONLY_BRANCH/terraform.tfstate" \
              -backend-config="region=ap-southeast-1"

            terraform apply -target="module.acm[\\"alb_cert\\"]" -auto-approve

            terraform apply -auto-approve \
              -var="environment=$ONLY_BRANCH"
          '''
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
