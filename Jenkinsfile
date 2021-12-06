pipeline {
  
  environment {
    // shouldn't need the registry variable unless you're not using dockerhub
    // registry = 'registry.hub.docker.com'
    //
    // change this HUB_CREDENTIAL to the ID of whatever jenkins credential has your registry user/pass
    // first let's set the docker hub credential and extract user/pass
    // we'll use the USR part for figuring out where are repository is
    HUB_CREDENTIAL = "docker-hub"
    // use credentials to set DOCKER_HUB_USR and DOCKER_HUB_PSW
    DOCKER_HUB = credentials("${HUB_CREDENTIAL}")
    // change repository to your DockerID
    REPOSITORY = "${DOCKER_HUB_USR}/${JOB_BASE_NAME}"
    // what package do we want to block?
    BLOCKED_PACKAGE = "curl"
  } // end environment
  
  agent any
  stages {
    
    stage('Checkout SCM') {
      steps {
        checkout scm
      } // end steps
    } // end stage "checkout scm"
   
    stage('Verify Tools') {
      steps {
        // check for docker and curl,
        // install/update syft, /var/jenkins_home should be writable 
        // also if you've set up jenkins in a docker container, this dir should be a persistent volume
        sh """
          which docker
          which curl
          which jq
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /var/jenkins_home/bin
          """
      } // end steps
    } // end stage "Verify Tools"
    
    stage('Build Image') {
      steps {
        sh """
          docker login -u ${DOCKER_HUB_USR} -p ${DOCKER_HUB_PSW}
          docker build -t ${REPOSITORY}:${BUILD_NUMBER} --pull -f ./Dockerfile .
        """
      } // end steps
    } // end stage "build and push"
    
    // I don't like using the docker plugin, but if you do:
    // stage('Build image and tag with build number') {
    //  steps {
    //    script {
    //      dockerImage = docker.build REPOSITORY + ":${BUILD_NUMBER}"
    //    } // end script
    //   } // end steps
    // } // end stage "build image and tag w build number"
    
    stage('Analyze with syft') {
      steps {
        // catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
        //   sh '/var/jenkins_home/bin/syft -o spdx-json ${REPOSITORY}:${BUILD_NUMBER} | tee ${JOB_BASE_NAME}.spdx.json | jq .packages[].name | tr "\n" " " | grep -qv ${BLOCKED_PACKAGE}'
        // }
        script {
          try {
            // run syft, use jq to get the list of artifact names, concatenate 
            // output to a single line and test that curl isn't in that line
            // the grep will fail if curl exists, causing the pipeline to fail
            //
            // this method uses native syft sbom instead of spdx:
            // sh '/var/jenkins_home/bin/syft -o json ${REPOSITORY}:${BUILD_NUMBER} | jq .artifacts[].name | tr "\n" " " | grep -qv curl'
            //
            sh """
              /var/jenkins_home/bin/syft -o spdx-json ${REPOSITORY}:${BUILD_NUMBER} | \
              tee ${JOB_BASE_NAME}.spdx.json | \
              jq .packages[].name | \
              tr "\n" " " | grep -qv ${BLOCKED_PACKAGE}
             """
          } catch (err) {
            // if scan fails, archive sbom, clean up (delete the image) and fail the build
            archiveArtifacts artifacts: '*.spdx.json'
            sh """
              echo "Blocked package detected in ${REPOSITORY}:${BUILD_NUMBER}, cleaning up and failing build."
              docker rmi ${REPOSITORY}:${BUILD_NUMBER}
              exit 1
            """
          } // end try/catch
        } // end script
      } // end steps
    } // end stage "analyze with syft"
    
    stage('Re-tag as prod and push stable image to registry') {
      steps {
        sh """
          docker tag ${REPOSITORY}:${BUILD_NUMBER} ${REPOSITORY}:prod
          docker push ${REPOSITORY}:prod
        """
        // I don't really like using the docker plug-in, but if you do, something like this:
        //script {
        //  docker.withRegistry('', HUB_CREDENTIAL) {
        //    dockerImage.push('prod') 
        //    // dockerImage.push takes the argument as a new tag for the image before pushing
        //  }
        //} // end script
      } // end steps
    } // end stage "retag as prod"

    stage('Clean up') {
      steps {
        // archive the sbom
        archiveArtifacts artifacts: '*.spdx.json'
        // delete the images locally
        sh 'docker rmi ${REPOSITORY}:${BUILD_NUMBER} ${REPOSITORY}:prod'
      } // end steps
    } // end stage "clean up"

    
  } // end stages
} //end pipeline
