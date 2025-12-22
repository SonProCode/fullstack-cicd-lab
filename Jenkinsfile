pipeline {
  agent any

  environment {
    REGISTRY = "thson20210744"
    BACKEND_IMAGE = "fullstack-backend"
    FRONTEND_IMAGE = "fullstack-frontend"
    TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
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

  post {
    success {
      echo "CI SUCCESS – Images pushed with tag: $TAG"
    }
    failure {
      echo "CI FAILED"
    }
  }
}
