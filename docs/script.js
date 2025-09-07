function redirectToApp(schemeBase) {
    const queryString = window.location.search;
    const fullSchemeUrl = `${schemeBase}${queryString}`;

    var url = URL.parse(fullSchemeUrl);

    console.log(queryString);

    /*let item = document.getElementById("text");
    let text = item.innerText;

    item.innerText = text.replace("%s", url.searchParams.get("query") ?? "(empty)")
    */
    
    window.location.href = fullSchemeUrl;

    setTimeout(() => {
        document.getElementById("banner").style.display = "block";
    }, 1500);
}

const path = window.location.pathname.split("/").filter(Boolean).pop();

switch (path) {
    case "search":
        redirectToApp("nokubooru://search");
        break;
    case "post":
        redirectToApp("nokubooru://post");
        break;
    case "viewer":
        redirectToApp("nokubooru://viewer");
        break;
    case "error":
        redirectToApp("nokubooru://error");
        break;
    default:
        document.getElementById("banner").style.display = "block";
        break;
}
