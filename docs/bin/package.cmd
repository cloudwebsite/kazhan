@echo off
cd /d "%~dp0.."
call yarn docs:build
