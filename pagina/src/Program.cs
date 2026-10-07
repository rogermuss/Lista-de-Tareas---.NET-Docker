var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => Results.Content(
"""
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>Lista de tareas</title>
  <link rel="stylesheet" href="/css/estilo.css">
</head>
<body>
  <ul>
  </ul>
</body>
</html>
""", "text/html"
));

app.Run();
