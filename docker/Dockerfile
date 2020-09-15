FROM julia:latest

ENV USER pluto
ENV USER_HOME_DIR /home/${USER}
ENV JULIA_DEPOT_PATH ${USER_HOME_DIR}/.julia
ENV NOTEBOOK_DIR ${USER_HOME_DIR}/notebooks
ENV JULIA_NUM_THREADS 100

RUN useradd -m -d ${USER_HOME_DIR} ${USER} \
    && mkdir ${NOTEBOOK_DIR} \
    && chown -R ${USER} ${USER_HOME_DIR}

USER ${USER}
RUN julia -e 'using Pkg; Pkg.update(); Pkg.add(["Pluto", "PlutoUI", "Plots"]); Pkg.precompile();'

EXPOSE 1234
VOLUME ${NOTEBOOK_DIR}
WORKDIR ${NOTEBOOK_DIR}

COPY docker_main.jl ${USER_HOME_DIR}
CMD [ "julia", "/home/pluto/docker_main.jl" ]
