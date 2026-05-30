@rem Copyright 2015 the original authors.
@rem Licensed under the Apache License, Version 2.0
@rem https://www.apache.org/licenses/LICENSE-2.0

@if "%DEBUG%"=="" @echo off
@rem NOTE: gradle-wrapper.jar is not committed.
@rem Run `gradle wrapper --gradle-version 8.11.1` to regenerate before use.

@setlocal

set APP_HOME=%~dp0
set APP_BASE_NAME=%~n0

set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar

if defined JAVA_HOME (
    set JAVACMD=%JAVA_HOME%\bin\java.exe
) else (
    set JAVACMD=java.exe
)

"%JAVACMD%" -Xmx64m -Xms64m %JAVA_OPTS% %GRADLE_OPTS% ^
    "-Dorg.gradle.appname=%APP_BASE_NAME%" ^
    -classpath "%CLASSPATH%" ^
    org.gradle.wrapper.GradleWrapperMain %*

@endlocal
