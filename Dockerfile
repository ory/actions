ARG GO_VERSION=1.14.4
ARG NODE_VERSION=14.5.0
ARG GORELEASER_VERSION=0.139.0

# OS-X SDK parameters
# NOTE: when changing version here, make sure to also change OSX_CODENAME below to match
ARG OSX_SDK=MacOSX10.10.sdk
ARG OSX_SDK_SUM=631b4144c6bf75bf7a4d480d685a9b5bda10ee8d03dbf0db829391e2ef858789

# OSX-cross parameters. Go 1.11 requires OSX >= 10.10
ARG OSX_VERSION_MIN=10.10
ARG OSX_CROSS_COMMIT=a9317c18a3a457ca0a657f08cc4d0d43c6cf8953

# Libtool parameters
ARG LIBTOOL_VERSION=2.4.6
ARG OSX_CODENAME=yosemite

FROM golang:${GO_VERSION}-buster AS base
ARG NODE_VERSION
ARG APT_MIRROR
RUN sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
 && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list
ENV OSX_CROSS_PATH=/osxcross

FROM base AS osx-sdk
ARG OSX_SDK
ARG OSX_SDK_SUM
ADD https://s3.dockerproject.org/darwin/v2/${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"
RUN echo "${OSX_SDK_SUM}"  "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c -

FROM base AS osx-cross-base
ARG DEBIAN_FRONTEND=noninteractive
# Dependencies for https://github.com/tpoechtrager/osxcross:
# TODO split these into "build-time" and "runtime" dependencies so that build-time deps do not end up in the final image
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
    clang \
    file \
    llvm \
    patch \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

FROM osx-cross-base AS osx-cross
ARG OSX_CROSS_COMMIT
WORKDIR "${OSX_CROSS_PATH}"
RUN git clone https://github.com/tpoechtrager/osxcross.git . \
 && git checkout -q "${OSX_CROSS_COMMIT}" \
 && rm -rf ./.git
COPY --from=osx-sdk "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ARG OSX_VERSION_MIN
RUN UNATTENDED=yes OSX_VERSION_MIN=${OSX_VERSION_MIN} ./build.sh

FROM base AS libtool
ARG LIBTOOL_VERSION
ARG OSX_CODENAME
ARG OSX_SDK
RUN mkdir -p "${OSX_CROSS_PATH}/target/SDK/${OSX_SDK}/usr/"
RUN curl -fsSL "https://homebrew.bintray.com/bottles/libtool-${LIBTOOL_VERSION}.${OSX_CODENAME}.bottle.tar.gz" \
	| gzip -dc | tar xf - \
		-C "${OSX_CROSS_PATH}/target/SDK/${OSX_SDK}/usr/" \
		--strip-components=2 \
		"libtool/${LIBTOOL_VERSION}/include/" \
		"libtool/${LIBTOOL_VERSION}/lib/"

FROM osx-cross-base AS final
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
    libltdl-dev \
    gcc-mingw-w64 \
    musl-tools \
    parallel \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common \
    gettext \
    jq \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable"
RUN apt-get update -qq && apt-get  -y -q --no-install-recommends install docker-ce docker-ce-cli containerd.io

ARG GORELEASER_VERSION
ARG NODE_VERSION
ARG GORELEASER_DOWNLOAD_FILE=goreleaser_Linux_x86_64.tar.gz
ARG GORELEASER_DOWNLOAD_URL=https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_DOWNLOAD_FILE}

# NodeJS
RUN mkdir -p /usr/local/nvm
ENV NVM_DIR /usr/local/nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default

ENV NODE_PATH $NVM_DIR/v${NODE_VERSION}/lib/node_modules
ENV PATH      $NVM_DIR/v${NODE_VERSION}/bin:$PATH

# goreleaser
RUN wget ${GORELEASER_DOWNLOAD_URL}; \
			tar -xzf $GORELEASER_DOWNLOAD_FILE -C /usr/bin/ goreleaser; \
			rm $GORELEASER_DOWNLOAD_FILE;

# go-swagger
RUN download_url=$(curl -s https://api.github.com/repos/go-swagger/go-swagger/releases/latest \
    | jq -r '.assets[] | select(.name | contains("'"$(uname | tr '[:upper:]' '[:lower:]')"'_amd64")) | .browser_download_url') \
    && curl -o $GOPATH/bin/swagger -L'#' "$download_url" \
    && chmod +x $GOPATH/bin/swagger

# ORY CLI
# Let's build from source instead...
# RUN curl -sSfL https://raw.githubusercontent.com/ory/cli/master/install.sh | sh -s -- -b $(go env GOPATH)/bin

# golangci-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.27.0

# goreturns
RUN go get github.com/sqs/goreturns github.com/ory/go-acc

RUN mkdir -p cd $(go env GOPATH)/src/github.com/ory/cli; \
    cd $(go env GOPATH)/src/github.com/ory/cli; \
    git clone https://github.com/ory/cli.git .; \
    go build -tags sqlite -o $(go env GOPATH)/bin/ory github.com/ory/cli

RUN git config --global user.email "3372410+aeneasr@users.noreply.github.com"
RUN git config --global user.name "aeneasr"

RUN apt -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable" \
    && apt update \
    && apt -y install docker-ce docker-ce-cli containerd.io

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
COPY --from=libtool   "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH

VOLUME /project
WORKDIR /project

RUN go version
RUN node --version
RUN ory version
RUN golangci-lint version

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
