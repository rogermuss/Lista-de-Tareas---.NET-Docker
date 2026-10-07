var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var tareas = new List<Tarea>();

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

app.MapPost("/tasks", (HttpRequest request) =>
{
    if (!request.HasFormContentType)
      return Results.BadRequest();

    var text = request.Form["text"].ToString();         

    if (string.IsNullOrWhiteSpace(text))                              
        return Results.BadRequest();               //respuesta 400
    

    tareas.Add(new Tarea(Guid.NewGuid().ToString(), text, false)); 

    return Results.Redirect("/");
});

app.Run();

record Tarea(string Id,string Text, bool Done);