FROM ubuntu:18.04 AS qpid-builder

ARG DEBIAN_FRONTEND=noninteractive
# Install all the required packages. Some in this list were picked off from proton's INSTALL.md (https://github.com/apache/qpid-proton/blob/master/INSTALL.md) and the rest are from dispatch (https://github.com/apache/qpid-dispatch/blob/master/README)
RUN apt-get update && \
    apt-get install -y gcc g++ automake libwebsockets-dev libtool zlib1g-dev cmake libsasl2-dev libssl-dev python python-dev libuv1-dev sasl2-bin swig maven git && \
    apt-get -y clean

RUN git clone -b 1.14.0 --single-branch https://gitbox.apache.org/repos/asf/qpid-dispatch.git && cd /qpid-dispatch && git submodule add https://gitbox.apache.org/repos/asf/qpid-proton.git
RUN cd /qpid-dispatch/qpid-proton && git checkout 0.31.0 && cd /qpid-dispatch && git submodule update --init

WORKDIR /qpid-dispatch

RUN mkdir qpid-proton/build && cd qpid-proton/build && cmake .. -DSYSINSTALL_BINDINGS=ON -DCMAKE_INSTALL_PREFIX=/usr -DSYSINSTALL_PYTHON=ON && make install

WORKDIR /qpid-dispatch

RUN mkdir build && cd build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DUSE_VALGRIND=NO && cmake --build . --target install

FROM golang:latest AS go-builder

RUN mkdir -p /go/src/github.com/eclipse-iofog/router
WORKDIR /go/src/github.com/eclipse-iofog/router
COPY . /go/src/github.com/eclipse-iofog/router
RUN go build -o bin/router

FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y python iputils-ping && \
    apt-get -y clean

COPY --from=qpid-builder /usr/lib/lib* /usr/lib/
COPY --from=qpid-builder /usr/lib/qpid-dispatch /usr/lib/qpid-dispatch
COPY --from=qpid-builder /usr/lib/python2.7 /usr/lib/python2.7
COPY --from=qpid-builder /usr/lib/ssl /usr/lib/ssl
COPY --from=qpid-builder /usr/lib/sasl2 /usr/lib/sasl2
COPY --from=qpid-builder /usr/lib/openssh /usr/lib/openssh
COPY --from=qpid-builder /usr/lib/*-linux-* /usr/lib/
COPY --from=qpid-builder /usr/sbin/qdrouterd /usr/sbin/qdrouterd
COPY --from=qpid-builder /usr/bin/qdmanage /usr/bin/qdmanage
COPY --from=qpid-builder /usr/bin/qdstat /usr/bin/qdstat

COPY --from=go-builder /go/src/github.com/eclipse-iofog/router/bin/router /qpid-dispatch/router

COPY scripts/launch.sh /qpid-dispatch/launch.sh

ENV PYTHONPATH=/usr/lib/python2.7/site-packages

# CMD ["/qpid-dispatch/router"]
ENTRYPOINT ["qdrouterd"]
