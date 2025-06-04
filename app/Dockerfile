FROM amazoncorretto:21-alpine-jdk

ARG JAR_FILE=*.jar
COPY target/${JAR_FILE} app.jar

# Variáveis de ambiente para sua aplicação (ex: nome do bucket S3)
# ENV S3_BUCKET_NAME="meu-bucket-unico-para-app"

ENTRYPOINT ["java","-jar","/app.jar"]

# Exponha a porta que sua aplicação Spring Boot usa (padrão 8080)
EXPOSE 8080