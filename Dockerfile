# Build Apache Qpid Dispatch
FROM ubuntu:latest AS qpid-builder

ENV TZ=America/New_York
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y curl gcc g++ automake libwebsockets-dev libtool zlib1g-dev cmake libsasl2-dev libssl-dev python3 python3-dev libuv1-dev sasl2-bin swig maven git && \
    apt-get -y clean

RUN git clone -b 1.18.0 --single-branch https://gitbox.apache.org/repos/asf/qpid-dispatch.git

WORKDIR /qpid-dispatch
RUN git submodule add -b v3.0-stable https://github.com/warmcat/libwebsockets
RUN git submodule add https://gitbox.apache.org/repos/asf/qpid-proton.git && cd qpid-proton/ && git checkout 0.36.0

# Transform deprecated errors into warning until we get this qpid thing sorted out
RUN sed -i 's/-Werror/-Werror -Wno-error=deprecated-declarations/g' /qpid-dispatch/libwebsockets/CMakeLists.txt
RUN sed -i 's/-Werror/-Werror -Wno-error=deprecated-declarations/g' /qpid-dispatch/qpid-proton/CMakeLists.txt

RUN mkdir libwebsockets/build && cd /qpid-dispatch/libwebsockets/build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr && make install

WORKDIR /qpid-dispatch
RUN mkdir qpid-proton/build && cd qpid-proton/build && cmake .. -DSYSINSTALL_BINDINGS=ON -DCMAKE_INSTALL_PREFIX=/usr -DSYSINSTALL_PYTHON=ON && make install

WORKDIR /qpid-dispatch
RUN mkdir build && cd build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DUSE_VALGRIND=NO && cmake --build . --target install

# Build ioFog Router utility
FROM golang:1.16.7 AS go-builder

RUN mkdir -p /go/src/github.com/eclipse-iofog/router
WORKDIR /go/src/github.com/eclipse-iofog/router
COPY . /go/src/github.com/eclipse-iofog/router
RUN go build -o bin/router

# Build final image
FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y python3 python3-dev iputils-ping libsasl2-modules nano && \
    apt-get -y clean

COPY --from=qpid-builder /usr/lib/lib* /usr/lib/
COPY --from=qpid-builder /usr/lib/python3 /usr/lib/python3
COPY --from=qpid-builder /usr/lib/python3.9 /usr/lib/python3.9
COPY --from=qpid-builder /usr/lib/ssl /usr/lib/ssl
COPY --from=qpid-builder /usr/lib/sasl2 /usr/lib/sasl2
COPY --from=qpid-builder /usr/lib/openssh /usr/lib/openssh
COPY --from=qpid-builder /usr/lib/*-linux-* /usr/lib/
COPY --from=qpid-builder /usr/sbin/qdrouterd /usr/sbin/qdrouterd
COPY --from=qpid-builder /usr/bin/qdmanage /usr/bin/qdmanage
COPY --from=qpid-builder /usr/bin/qdstat /usr/bin/qdstat

COPY --from=qpid-builder /usr/lib/qpid-dispatch /usr/lib/qpid-dispatch
COPY --from=qpid-builder /usr/include/qpid /usr/include/qpid

COPY --from=qpid-builder /usr/share/proton /usr/share/proton
COPY --from=qpid-builder /usr/include/proton /usr/include/proton
COPY --from=qpid-builder /usr/lib/pkgconfig/libqpid* /usr/lib/pkgconfig/
COPY --from=qpid-builder /usr/lib/cmake/Proton /usr/lib/cmake/Proton
COPY --from=qpid-builder /usr/share/proton /usr/share/proton

# Silly hack to fix layer issue in Azure Devops :-/
RUN true
COPY --from=go-builder /go/src/github.com/eclipse-iofog/router/bin/router /qpid-dispatch/router

COPY scripts/launch.sh /qpid-dispatch/launch.sh

ENV PYTHONPATH=/usr/lib/python3.9/site-packages

CMD ["/qpid-dispatch/router"]
