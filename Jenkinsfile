pipeline {
  agent any

  parameters {
    choice(name: 'ACTION', choices: ['deploy', 'destroy'], description: 'deploy ships the app; destroy removes what Terraform made')
    string(name: 'REPLICAS', defaultValue: '2', description: 'Pods Ansible asks for')
    string(name: 'MESSAGE', defaultValue: 'Hello from Terraform', description: 'Goes into the ConfigMap')
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 30, unit: 'MINUTES')
  }

  environment {
    KUBECONFIG     = credentials('kubeconfig-lab')  // Secret file: path to a temp copy
    IMAGE          = 'hello-hcl'
    TAG            = "${env.BUILD_NUMBER}"
    TF_VAR_message = "${params.MESSAGE}"
    TF_IN_AUTOMATION = 'true'
  }

  stages {
    stage('Tool check') {
      steps {
        sh '''
          docker version --format 'Docker {{.Server.Version}}'
          kind version
          kubectl version --client
          terraform version
          ansible --version | head -1
          kubectl get nodes
        '''
      }
    }

    stage('Build image') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        sh 'docker build -t $IMAGE:$TAG app/'
      }
    }

    stage('Test image') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        sh 'docker run --rm $IMAGE:$TAG cat /usr/share/nginx/html/index.html | grep -q "Hello HCL"'
      }
    }

    stage('Load into kind') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        sh 'kind load docker-image $IMAGE:$TAG --name lab'
      }
    }

    stage('Terraform plan') {
      steps {
        dir('terraform') {
          sh '''
            terraform init -input=false
            if [ "$ACTION" = "destroy" ]; then MODE="-destroy"; else MODE=""; fi
            terraform plan -input=false $MODE -var "kubeconfig=$KUBECONFIG" -out tfplan
            terraform show -no-color tfplan > plan.txt
          '''
          archiveArtifacts artifacts: 'plan.txt'
        }
      }
    }

    stage('Approve') {
      steps {
        input message: "Apply this Terraform plan (${params.ACTION})?", ok: 'Apply'
      }
    }

    stage('Terraform apply') {
      steps {
        dir('terraform') {
          sh 'terraform apply -input=false tfplan'
        }
      }
    }

    stage('Ansible deploy') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        sh 'ansible-playbook -i localhost, ansible/deploy.yml -e image_tag=$TAG -e replicas=$REPLICAS -e kubeconfig=$KUBECONFIG'
      }
    }

    stage('Verify') {
      when { expression { params.ACTION == 'deploy' } }
      steps {
        sh '''
          kubectl -n hcl-lab get deploy,pods,svc
          kubectl -n hcl-lab exec deploy/hello-hcl -- wget -qO- http://localhost
          kubectl -n hcl-lab exec deploy/hello-hcl -- printenv MESSAGE
        '''
      }
    }
  }

  post {
    failure {
      sh 'kubectl -n hcl-lab get events --sort-by=.lastTimestamp | tail -20 || true'
    }
    always {
      echo "Build ${env.BUILD_NUMBER} finished: ${currentBuild.currentResult}"
    }
  }
}
