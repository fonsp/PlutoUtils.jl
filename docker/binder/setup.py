import setuptools
import os

setuptools.setup(
    name="jupyter_pluto_proxy",
    packages=setuptools.find_packages(),
    install_requires=[
        'jupyter-server-proxy'
    ],
    entry_points={
        "jupyter_serverproxy_servers": ["pluto = jupyter_pluto_proxy:setup_pluto",]
    },
    package_data={"jupyter_pluto_proxy": ["icons/*"]},
)

