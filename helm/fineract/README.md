Use this pipeline to run fineract helm chart

```

pipeline { 

  environment { 
      tag = sh(returnStdout: true, script: "git rev-parse --short=10 HEAD | sed 's/[^a-zA-Z0-9]/-/g'").trim()
  }
  
  options {
        skipStagesAfterUnstable()
  }
  
  triggers { 
    githubPush() 
  }

  agent any

   
  stages { 
      stage('Cloning from Git') { 
          steps { 
              git url: 'https://github.com/fynarfin/fineract-env.git/', branch: 'master' 
          }
      } 
  

      stage('Build Helm Chart') { 
          steps {
              sh 'rm -f helm/fineract/Chart.lock helm/fineract/requirements.lock helm/fineract/charts/*'
              sh 'helm dep up helm/fineract'
              sh 'helm package helm/fineract'
              sh 'helm repo index .'
          }
      }
      
      stage('Uploading Helm Chart') {
          steps {
              sh  'scp -o StrictHostKeyChecking=No -i /var/lib/jenkins/fynarfin.pem index.yaml fin-engine-1.0.0-SNAPSHOT.tgz ec2-user@13.233.68.128:~/'
              sh  'ssh -i /var/lib/jenkins/fynarfin.pem -o StrictHostKeyChecking=No ec2-user@13.233.68.128 sudo mv -t /apps/apache-tomcat-7.0.82/webapps/ROOT/images/fineract index.yaml fin-engine-1.0.0-SNAPSHOT.tgz'
          }
      }
      
      stage('Deploy Helm Chart') { 
          steps {
              sh 'kubectl config use-context sit/c93ikeqw0u99kkbi48t0'
              sh 'rm -f helm/fineract/Chart.lock helm/fineract/requirements.lock helm/fineract/charts/*'
              sh 'helm dep up helm/fineract'
              sh 'helm uninstall fineract'
              sh 'helm upgrade -f helm/fineract/values.yaml fineract helm/fineract --install --create-namespace --namespace default '
          }
      }

  }
  
}
      

```
