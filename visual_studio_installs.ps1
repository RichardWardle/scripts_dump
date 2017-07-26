# Generic script which installs the visual studio code located in your folder visual. They must be named vcredist_ARCH_YEAR.exe
# Each year has its own method of paramters for installing, be more efficient to have one function

try 
{
    if ((-not $(Test-path -path visual)) -or ($(get-childitem visual).Count -eq 0))
    { 
        Write-Output "The folder visual in this directory does not exsist OR it is empty"
        Exit 2
    }

    Write-Output "This installs all the visual studio code in the folder visual\ located in the place this script was run"

    if ([System.IntPtr]::Size -eq 8) 
    {
        Write-output "We are a 64bit machine so install 64bit versions"
        install64bit
        
        Write-output "We are a 64bit machine so install 32bit versions given some of our code relies on this"
        install32bit

    }
    else
    {
        Write-output "We are a 32bit machine so install 32bit versions only"
        install32bit
    }
}
catch
{
    Write-Output "Something went wrong please check log messages"
    Write-Output $_.Exception.Message
    Exit 2
}

function install32Bit
{
    Write-Output "Installing/Repairing Visual Studio 2008 x32"
    .\visual\vcredist_x32_2008.exe /qb

    Write-Output "Installing/Repairing Visual Studio 2010 x32"
    .\visual\vcredist_x32_2010.exe /passive /norestart

    Write-Output "Installing/Repairing Visual Studio 2013 x32"
    .\visual\vcredist_x32_2013.exe /install /passive /norestart

    Write-Output "Installing/Repairing Visual Studio 2015 x32"
    .\visual\vcredist_x32_2015.exe /install /passive /norestart
}

function install64bit
{
    Write-Output "Installing Repairing Visual Studio 2008 x64"
    .\visual\vcredist_x64_2008.exe /qb

    Write-Output "Installing Repairing Visual Studio 2010 x64"
    .\visual\vcredist_x64_2010.exe /passive /norestart

    Write-Output "Installing Repairing Visual Studio 2013 x64"
    .\visual\vcredist_x64_2013.exe /install /passive /norestart

    Write-Output "Installing Repairing Visual Studio 2015 x64"
    .\visual\vcredist_x64_2015.exe /install /passive /norestart
}
