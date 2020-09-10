FROM julia:latest as builder

RUN apt-get update \
    && apt-get -y install clang \
    && rm -rf /var/lib/apt/lists/*

ENV USER pluto
ENV USER_HOME_DIR /home/${USER}
ENV DEBIAN_FRONTEND=noninteractive
ENV JULIA_DEPOT_PATH ${USER_HOME_DIR}/.julia
ENV NOTEBOOK_DIR ${USER_HOME_DIR}/notebooks
ENV JULIA_NUM_THREADS=100

RUN useradd -m -d ${USER_HOME_DIR} ${USER} \
    && mkdir ${NOTEBOOK_DIR}

WORKDIR ${USER_HOME_DIR}
COPY *.jl ${USER_HOME_DIR}/
RUN julia create_sysimage.jl
RUN julia precompile.jl

FROM julia:latest
ENV USER pluto
ENV USER_HOME_DIR /home/${USER}
ENV DEBIAN_FRONTEND=noninteractive
ENV JULIA_DEPOT_PATH ${USER_HOME_DIR}/.julia
ENV NOTEBOOK_DIR ${USER_HOME_DIR}/notebooks
ENV JULIA_NUM_THREADS=100

RUN useradd -m -d ${USER_HOME_DIR} ${USER} \
    && mkdir ${NOTEBOOK_DIR}

WORKDIR ${USER_HOME_DIR}
COPY *.jl ${USER_HOME_DIR}/

COPY --from=builder /usr/local/julia/lib/julia/sys.so /usr/local/julia/lib/julia/sys.so
RUN julia prestartup.jl

RUN chown -R ${USER} ${USER_HOME_DIR}
USER ${USER}

EXPOSE 1234
VOLUME ${NOTEBOOK_DIR}
WORKDIR ${NOTEBOOK_DIR}

CMD [ "julia", "/home/pluto/startup.jl" ]


