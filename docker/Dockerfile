FROM julia:latest

RUN useradd -m pluto

EXPOSE 1234

ENV JULIA_NUM_THREADS = 100
ENV JULIA_DEPOT_PATH=/home/pluto/.julia

USER pluto
RUN julia -e 'using Pkg; Pkg.update(); Pkg.add(["Pluto", "PlutoUI", "Plots"]); Pkg.precompile();'

VOLUME /home/pluto/notebooks
WORKDIR /home/pluto/notebooks

COPY docker_main.jl /home/pluto
CMD [ "julia", "/home/pluto/docker_main.jl" ]
