FROM mcr.microsoft.com/dotnet/sdk:10.0
WORKDIR /app
COPY pagina/src/ .
COPY comun/ comun/
ENV ASPNETCORE_URLS=http://+:7070
EXPOSE 7070
CMD ["dotnet", "run", "--no-launch-profile"]