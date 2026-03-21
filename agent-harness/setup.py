from setuptools import setup, find_namespace_packages

setup(
    name="cli-anything-emaxforge",
    version="0.1.0",
    description="CLI-Anything harness for EmaxForge - EMAX II disk management",
    author="AI Agent",
    author_email="agent@openclaw.ai",
    packages=find_namespace_packages(include=["cli_anything.*"]),
    install_requires=[
        "click>=8.0.0",
    ],
    entry_points={
        "console_scripts": [
            "cli-anything-emaxforge=cli_anything.emaxforge.__main__:main",
        ],
    },
    python_requires=">=3.8",
)
