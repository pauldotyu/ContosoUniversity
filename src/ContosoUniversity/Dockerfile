FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src

# Copy csproj and restore
COPY *.csproj .
RUN dotnet restore

# Copy everything else and build
COPY . .
RUN dotnet build -c release -o /release --no-restore

# Publish the build
FROM build as publish
RUN dotnet publish -c release -o /publish --no-restore

# Serve app using aspnet 5.0 runtime
FROM mcr.microsoft.com/dotnet/aspnet:5.0 as serve
WORKDIR /app
COPY --from=publish /publish .
ENTRYPOINT [ "dotnet", "ContosoUniversity.dll" ]