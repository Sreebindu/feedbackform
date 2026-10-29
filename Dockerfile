FROM httpd:2.4

WORKDIR /usr/local/apache2/htdocs/

COPY index.html /usr/local/apache2/htdocs/index.html

RUN echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80

ENTRYPOINT ["httpd"]

CMD ["-D", "FOREGROUND"]
