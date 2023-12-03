const http = require('http');
const os = require('os');

const hostname = '0.0.0.0';
const port = 3000;

const formatSystemInfo = () => {
    const osInfo = `OS: ${os.type()} ${os.release()} (${os.arch()})`;
    const cloudProvider = process.env.CLOUD_PROVIDER || 'Local';
    return `<!doctype html>
            <html>
            <head>
                <meta charset="UTF-8">
                <title>UNIR Actividad1</title>
            </head>
            <body>
            <style>
                body {
                    font-family: "Century Gothic",Verdana,sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    margin: 0;
                }

                div {
                    text-align: center;
                }
            </style>
            <div>
                <h1>Hola <b>Carlos Colón</b>!</h1>
                <h2>${osInfo}</h2>
                <h2>Cloud Provider: ${cloudProvider}</h2>
            </div>
            </body>`;
};

const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/html');

    if (req.url === '/') {
        res.end(formatSystemInfo());    // Ruta predeterminada
    } else if (req.url === '/ping') {
        res.end('pong\n');              // Ruta /ping
    } else {
        res.statusCode = 404;           // Para cualquier otra ruta devolver un 404
        res.end('Not Found\n');
    }
});

server.listen(port, hostname, () => {
    console.log('Server running at http://' + hostname + ':' + port + '/');
});

