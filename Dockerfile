FROM ubuntu:18.04 AS qpid-builder

# https://github.com/apache/qpid-dispatch/blob/1.15.0/dockerfiles/Dockerfile-ubuntu
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y curl gcc g++ automake libwebsockets-dev libtool zlib1g-dev cmake libsasl2-dev libssl-dev libnghttp2-dev python3-dev libuv1-dev sasl2-bin swig maven git libxml2-dev libxslt1-dev && \
    apt-get -y clean

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py
RUN pip3 install quart
RUN pip3 install selectors
RUN pip3 install grpcio protobuf
RUN pip3 install lxml

RUN git clone -b 1.15.0 --single-branch https://gitbox.apache.org/repos/asf/qpid-dispatch.git && cd /qpid-dispatch && git submodule add https://gitbox.apache.org/repos/asf/qpid-proton.git
RUN cd /qpid-dispatch/qpid-proton && git checkout 0.33.0 && cd /qpid-dispatch && git submodule update --init

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
    apt-get install -y python3 python3-dev iputils-ping && \
    apt-get -y clean

COPY --from=qpid-builder /usr/lib/lib* /usr/lib/
COPY --from=qpid-builder /usr/lib/qpid-dispatch /usr/lib/qpid-dispatch
COPY --from=qpid-builder /usr/lib/python3.6 /usr/lib/python3.6
COPY --from=qpid-builder /usr/lib/ssl /usr/lib/ssl
COPY --from=qpid-builder /usr/lib/sasl2 /usr/lib/sasl2
COPY --from=qpid-builder /usr/lib/openssh /usr/lib/openssh
COPY --from=qpid-builder /usr/lib/*-linux-* /usr/lib/
COPY --from=qpid-builder /usr/sbin/qdrouterd /usr/sbin/qdrouterd
COPY --from=qpid-builder /usr/bin/qdmanage /usr/bin/qdmanage
COPY --from=qpid-builder /usr/bin/qdstat /usr/bin/qdstat

COPY --from=go-builder /go/src/github.com/eclipse-iofog/router/bin/router /qpid-dispatch/router

COPY scripts/launch.sh /qpid-dispatch/launch.sh

ENV PYTHONPATH=/usr/lib/python3.6/site-packages

CMD ["/qpid-dispatch/router"]
