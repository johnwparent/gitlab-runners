# escape=`
FROM mcr.microsoft.com/windows/server:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

# Install SSL certs from CA
RUN (certutil -generateSSTFromWU roots.sst) -AND (certutil -addstore -f root roots.sst) -AND (del roots.sst)

# Install chocolatey
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; `
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install git and python3.11
RUN choco install -y git.install gnupg
RUN choco install -y python --version=3.11.0
RUN choco install file

# Install spack requirements
RUN python -m pip install --upgrade pip setuptools wheel
RUN python -m pip install pyreadline boto3 pyyaml pytz minio requests clingo pywin32

# Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

# Install build tools including MSVC, CMake, Win-SDK
RUN `
    curl -SL --output vs_buildtools.exe https://aka.ms/vs/17/release/vs_buildtools.exe `
    && start /w vs_buildtools.exe --quiet --wait --norestart --nocache `
    --installPath "C:\Spack\BuildTools" `
    --add Microsoft.VisualStudio.Workload.VCTools `
    --add Microsoft.VisualStudio.Component.TestTools.BuildTools `
    --add Microsoft.VisualStudio.Component.VC.ASAN `
    --add Microsoft.VisualStudio.Component.VC.CMake.Project `
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    --add Microsoft.VisualStudio.Component.Windows10SDK.19041 `
    --add Microsoft.Component.VC.Runtime.UCRTSDK `
    --add Microsoft.VisualStudio.Component.VC.140 `
    --add Microsoft.VisualStudio.Component.VC.ATL `
    --add Microsoft.VisualStudio.Component.VC.ATLMFC `
    --add Microsoft.VisualStudio.Component.VC.CLI.Support `
    --add Microsoft.VisualStudio.Component.VC.v141.x86.x64 `
    && del /q vs_buildtools.exe


# download and install IntelOneAPI base toolkit (ifx) w/ msvc integration
ENV ONEAPI_FORTRAN_URL=https://registrationcenter-download.intel.com/akdlm/IRC_NAS/f6a44238-5cb6-4787-be83-2ef48bc70cba/w_fortran-compiler_p_2024.1.0.466_offline.exe
RUN `
    curl -SL --output oneapi_installer.exe %ONEAPI_FORTRAN_URL% `
    && start /w oneapi_installer.exe -s --remove-extracted-files yes -a --silent --eula accept`
    && del oneapi_installer.exe

# Set env vars
ENV NVIDIA_VISIBLE_DEVICES=all `
    NVIDIA_DRIVER_CAPABILITIES=compute,utility `
    LANGUAGE=en_US:en `
    LANG=en_US.UTF-8 `
    LC_ALL=en_US.UTF-8

ENTRYPOINT ["C:\\Spack\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
