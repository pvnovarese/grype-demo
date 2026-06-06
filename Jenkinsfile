pipeline {

  agent any
    // this is actually probably not a great idea, I only tested this on a single node setup
    // if you do this on a multi-node setup, you would need to install orca-cli on every node
    // that the tests could possibly end up on.

  options {
    // Kill the run if it hangs (e.g. a scan or buildx push that stalls)
    timeout(time: 30, unit: 'MINUTES')

    // Only one run at a time — prevents concurrent runs from fighting over
    // the shared buildx builder and the docker login/logout session
    disableConcurrentBuilds()

    // Keep the last 20 builds' logs/artifacts, discard older ones
    buildDiscarder(logRotator(numToKeepStr: '20'))

    // Prefix every console line with a timestamp (handy for scan timing)
    // (this needs the timestamper plugin, which is usually installed by default)
    timestamps()
  }
  
  environment {
    // Replace with your registry (if you're using container images, if not you can ignore this)
    REGISTRY      = 'docker.io'    //
    // what severity level do we want to gate on? (this is optional, see the "analyze with grype" stage)
    // VULN_THRESHOLD = "critical"
    // use GIT_BRANCH for when we "promote" image:
    BRANCH_NAME = "${GIT_BRANCH.split("/")[1]}"
  } // end environment
  
  stages {
    
    stage('Checkout SCM') {
      steps {
        checkout scm
      } // end steps
    } // end stage "checkout scm"
   
    stage('Verify Tools') {
      steps {
        // check for docker and curl,
        // install/update grype, /var/jenkins_home should be writable 
        // also if you've set up jenkins in a docker container, this dir should be a persistent volume
        sh """
          which docker
          which curl
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/.local/bin
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/.local/bin
          """
      } // end steps
    } // end stage "Verify Tools"
    
    stage('Build Image') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'docker-hub',
          usernameVariable: 'REGISTRY_USER',
          passwordVariable: 'REGISTRY_PASSWORD'
        )]) {
          script {
            // Setting env.IMAGE here makes it available to all subsequent stages
            // You can change this as needed, e.g. change the tag scheme, whatever
            env.IMAGE = "${REGISTRY}/${REGISTRY_USER}/${JOB_BASE_NAME}:build-${BUILD_NUMBER}"
          } // end script
          // log in to registry, // set up buildx, // Build and push the image
          sh '''
            echo "${REGISTRY_PASSWORD}" | docker login ${REGISTRY} -u "${REGISTRY_USER}" --password-stdin
            docker buildx inspect --bootstrap
            docker buildx build --push --tag ${IMAGE} .
          '''
        } // end withCredentials
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
    
    stage('Analyze with grype') {
      steps {
        // run syft and output syft-table to console and json to file, we'll archive that at the end
        sh '~/.local/bin/syft -o syft-table -o json=${JOB_BASE_NAME}.sbom.json ${IMAGE}'
        // run grype, output to console and save output to file, we'll archive that as well
        sh '~/.local/bin/grype -o table -o json=${JOB_BASE_NAME}.vuln.json sbom:${JOB_BASE_NAME}.sbom.json'
        //
        // you can do some analysis here, for example you can check for
        // critical vulns and break the pipeline if the image has any.
        // There is a variable in the environment section at the top of this
        // Jenkinsfile, you can uncomment that and set it to high, critical, etc
        // and then use this:
        //
        // sh """
        //   /var/jenkins_home/bin/grype -o json -f ${VULN_THRESHOLD} ${IMAGE} > ${JOB_BASE_NAME}.vuln.json
        // """
        //
      } // end steps
    } // end stage "analyze with grype"

    //
    // Congrats, you made it this far, now promote your image or do your QA tests or whatever
    //
    //stage('Promote and Push Image') {
    //  steps {
    //    withCredentials([usernamePassword(
    //      credentialsId: 'docker-hub',
    //      usernameVariable: 'REGISTRY_USER',
    //      passwordVariable: 'REGISTRY_PASSWORD'
    //    )]) {
    //      script {    
    //        sh """
    //          docker login -u ${REGISTRY_USER} -p ${REGISTRY_PASSWORD}
    //          docker tag ${IMAGE} ${REGISTRY}/${REGISTRY_USER}/${JOB_BASE_NAME}:${BRANCH_NAME}
    //          docker push ${REGISTRY}/${REGISTRY_USER}/${JOB_BASE_NAME}:${BRANCH_NAME}
    //        """
    //      } // end script
    //    } // end withCredentials
      //    // I don't really like using the docker plug-in, but if you do, something like this:
      //    //script {
      //    //  docker.withRegistry('', HUB_CREDENTIAL) {
      //    //    dockerImage.push('prod') 
      //    //    // dockerImage.push takes the argument as a new tag for the image before pushing
      //    //  }
      //    //} // end script
    //  } // end steps
    //} // end stage "retag as prod"
    
  } // end stages
  
  post {
    always {
      // archive the sbom
      archiveArtifacts artifacts: '*.json'
      // delete the images locally
      // clean up docker login credentials 
      sh '''
        docker image rm ${IMAGE} ${REGISTRY}/${REGISTRY_USER}/${JOB_BASE_NAME}:${BRANCH_NAME} || failure=1
        docker logout ${REGISTRY} || true
      '''
    } // end always
  } //end post
      
} //end pipeline
