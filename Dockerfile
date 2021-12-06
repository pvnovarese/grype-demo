# Dockerfile for sfyt CICD integration demonstration
# we will use syft to look for curl in the image 
# and kill the CICD pipeline if we find it
FROM alpine:3.13.1

LABEL maintainer="pvn@novarese.net"
LABEL name="grype-demo"
LABEL org.opencontainers.image.title="grype-demo"
LABEL org.opencontainers.image.description="Simple image to test CICD integration with Grype."

HEALTHCHECK --timeout=10s CMD /bin/true || exit 1

COPY Dockerfile /

## just to make sure we have a unique build each time
RUN apk add sudo curl && \
    date > /image_build_timestamp

USER nobody
ENTRYPOINT /bin/false
