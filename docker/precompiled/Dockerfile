FROM julia:latest

ENV USER pluto
ENV USER_HOME_DIR /home/${USER}
ENV JULIA_DEPOT_PATH ${USER_HOME_DIR}/.julia
ENV NOTEBOOK_DIR ${USER_HOME_DIR}/notebooks
ENV JULIA_NUM_THREADS = 100

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get -y install clang \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d ${USER_HOME_DIR} ${USER} \
    && mkdir ${NOTEBOOK_DIR}

WORKDIR ${USER_HOME_DIR}
COPY warmup.jl ${USER_HOME_DIR}

RUN julia -e 'using Pkg; \
    Pkg.add(["Pluto", "PlutoUI", "Plots", "PackageCompiler"]); \
	Pkg.precompile(); \
    using PackageCompiler; \
    create_sysimage([:Pluto, :PlutoUI]; precompile_execution_file="warmup.jl", replace_default=true)' \
    && rm /usr/local/julia/lib/julia/sys.so.backup

COPY docker_main.jl ${USER_HOME_DIR}

RUN chown -R ${USER} ${USER_HOME_DIR}
USER ${USER}

EXPOSE 1234
VOLUME ${NOTEBOOK_DIR}
WORKDIR ${NOTEBOOK_DIR}

CMD [ "julia", "/home/pluto/docker_main.jl" ]
