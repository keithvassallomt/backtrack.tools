// A CloudFront Function on every viewer request.
//
// - www.backtrack.tools answers with a permanent redirect to the same path on
//   backtrack.tools, which serves the site.
// - A path ending in "/" is a page's folder, and S3 knows nothing of a
//   folder's default page, so the bucket is asked for the folder's index.html.
// - A path whose last part has no extension, such as /guides/rewind, names a
//   page's folder without its slash. It redirects to /guides/rewind/, so that
//   the page's relative links resolve against the folder.
//
// Every other request goes on to the bucket unchanged.
function handler(event) {
    var request = event.request;
    var host = request.headers.host && request.headers.host.value;
    var uri = request.uri;
    if (host === 'www.backtrack.tools') {
        return redirect('https://backtrack.tools' + uri);
    }
    if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
    } else if (uri.slice(uri.lastIndexOf('/') + 1).indexOf('.') === -1) {
        return redirect(uri + '/');
    }
    return request;
}

function redirect(location) {
    return {
        statusCode: 301,
        statusDescription: 'Moved Permanently',
        headers: { location: { value: location } }
    };
}
