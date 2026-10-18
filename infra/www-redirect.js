// A CloudFront Function on every viewer request: www.backtrack.tools answers
// with a permanent redirect to the same path on backtrack.tools, which serves
// the site. Every other request goes on to the bucket unchanged.
function handler(event) {
    var request = event.request;
    var host = request.headers.host && request.headers.host.value;
    if (host === 'www.backtrack.tools') {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: { location: { value: 'https://backtrack.tools' + request.uri } }
        };
    }
    return request;
}
