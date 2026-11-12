(function () {
    'use strict';

    const apiOrigin = window.location.hostname === 'newtalentloans.local'
        ? 'http://api.newtalentloans.local'
        : (window.location.hostname === 'api.newtalentloans.local' ? window.location.origin : 'http://api.newtalentloans.local');
    function resolveUrl(input) {
        const original = input instanceof Request ? input.url : String(input);
        if (original.startsWith('/?recurso=')) return apiOrigin + original;
        let parsed;
        try {
            parsed = new URL(original, window.location.href);
        } catch (_) {
            return original;
        }

        if (parsed.origin === 'http://api.newtalentloans.local') return original;
        if (original.startsWith('http://') || original.startsWith('https://')) {
            throw new Error('Ruta API no autorizada. Use api.newtalentloans.local.');
        }
        return apiOrigin + (original.startsWith('/') ? original : '/' + original);
    }

    window.NTLApi = {
        origin: apiOrigin,
        url: resolveUrl,
        fetch: function (input, options) {
            const init = Object.assign({}, options || {}, { credentials: 'include' });
            return window.fetch(resolveUrl(input), init);
        }
    };
}());
