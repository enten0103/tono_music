(function () {
    // console polyfill for group/groupEnd in QuickJS
    if (typeof globalThis.console === 'undefined') globalThis.console = {};
    const c = globalThis.console;
    if (typeof c.log !== 'function') c.log = function () { };
    if (typeof c.warn !== 'function') c.warn = function () { };
    if (typeof c.error !== 'function') c.error = function () { };
    if (typeof c.info !== 'function') c.info = function () { };
    if (typeof c.group !== 'function') c.group = function () { try { c.log.apply(c, arguments); } catch (_) { } };
    if (typeof c.groupCollapsed !== 'function') c.groupCollapsed = function () { try { c.log.apply(c, arguments); } catch (_) { } };
    if (typeof c.groupEnd !== 'function') c.groupEnd = function () { };
    // 简易 MD5（用于校验）
    function md5(str) {
        function _ff(a, b, c, d, x, s, t) { a = a + ((b & c) | ((~b) & d)) + x + t; return (((a << s) | (a >>> (32 - s))) + b) | 0 }
        function _gg(a, b, c, d, x, s, t) { a = a + ((b & d) | (c & (~d))) + x + t; return (((a << s) | (a >>> (32 - s))) + b) | 0 }
        function _hh(a, b, c, d, x, s, t) { a = a + (b ^ c ^ d) + x + t; return (((a << s) | (a >>> (32 - s))) + b) | 0 }
        function _ii(a, b, c, d, x, s, t) { a = a + (c ^ (b | (~d))) + x + t; return (((a << s) | (a >>> (32 - s))) + b) | 0 }
        function _toBytes(s) {
            const utf8 = utf8Encode(s);
            const len = utf8.length;
            const with1 = new Uint8Array(((len + 9 + 63) >> 6) << 6);
            with1.set(utf8);
            with1[len] = 0x80;
            const bitLen = len * 8;
            const dv = new DataView(with1.buffer);
            dv.setUint32(with1.length - 8, bitLen & 0xffffffff, true);
            dv.setUint32(with1.length - 4, (bitLen / 0x100000000) >>> 0, true);
            return new Uint32Array(with1.buffer);
        }
        const x = _toBytes(String(str));
        let a = 1732584193, b = -271733879, c = -1732584194, d = 271733878;
        for (let i = 0; i < x.length; i += 16) {
            const oa = a, ob = b, oc = c, od = d;
            a = _ff(a, b, c, d, x[i + 0], 7, -680876936); d = _ff(d, a, b, c, x[i + 1], 12, -389564586); c = _ff(c, d, a, b, x[i + 2], 17, 606105819); b = _ff(b, c, d, a, x[i + 3], 22, -1044525330);
            a = _ff(a, b, c, d, x[i + 4], 7, -176418897); d = _ff(d, a, b, c, x[i + 5], 12, 1200080426); c = _ff(c, d, a, b, x[i + 6], 17, -1473231341); b = _ff(b, c, d, a, x[i + 7], 22, -45705983);
            a = _ff(a, b, c, d, x[i + 8], 7, 1770035416); d = _ff(d, a, b, c, x[i + 9], 12, -1958414417); c = _ff(c, d, a, b, x[i + 10], 17, -42063); b = _ff(b, c, d, a, x[i + 11], 22, -1990404162);
            a = _ff(a, b, c, d, x[i + 12], 7, 1804603682); d = _ff(d, a, b, c, x[i + 13], 12, -40341101); c = _ff(c, d, a, b, x[i + 14], 17, -1502002290); b = _ff(b, c, d, a, x[i + 15], 22, 1236535329);

            a = _gg(a, b, c, d, x[i + 1], 5, -165796510); d = _gg(d, a, b, c, x[i + 6], 9, -1069501632); c = _gg(c, d, a, b, x[i + 11], 14, 643717713); b = _gg(b, c, d, a, x[i + 0], 20, -373897302);
            a = _gg(a, b, c, d, x[i + 5], 5, -701558691); d = _gg(d, a, b, c, x[i + 10], 9, 38016083); c = _gg(c, d, a, b, x[i + 15], 14, -660478335); b = _gg(b, c, d, a, x[i + 4], 20, -405537848);
            a = _gg(a, b, c, d, x[i + 9], 5, 568446438); d = _gg(d, a, b, c, x[i + 14], 9, -1019803690); c = _gg(c, d, a, b, x[i + 3], 14, -187363961); b = _gg(b, c, d, a, x[i + 8], 20, 1163531501);
            a = _gg(a, b, c, d, x[i + 13], 5, -1444681467); d = _gg(d, a, b, c, x[i + 2], 9, -51403784); c = _gg(c, d, a, b, x[i + 7], 14, 1735328473); b = _gg(b, c, d, a, x[i + 12], 20, -1926607734);

            a = _hh(a, b, c, d, x[i + 5], 4, -378558); d = _hh(d, a, b, c, x[i + 8], 11, -2022574463); c = _hh(c, d, a, b, x[i + 11], 16, 1839030562); b = _hh(b, c, d, a, x[i + 14], 23, -35309556);
            a = _hh(a, b, c, d, x[i + 1], 4, -1530992060); d = _hh(d, a, b, c, x[i + 4], 11, 1272893353); c = _hh(c, d, a, b, x[i + 7], 16, -155497632); b = _hh(b, c, d, a, x[i + 10], 23, -1094730640);
            a = _hh(a, b, c, d, x[i + 13], 4, 681279174); d = _hh(d, a, b, c, x[i + 0], 11, -358537222); c = _hh(c, d, a, b, x[i + 3], 16, -722521979); b = _hh(b, c, d, a, x[i + 6], 23, 76029189);
            a = _hh(a, b, c, d, x[i + 9], 4, -640364487); d = _hh(d, a, b, c, x[i + 12], 11, -421815835); c = _hh(c, d, a, b, x[i + 15], 16, 530742520); b = _hh(b, c, d, a, x[i + 2], 23, -995338651);

            a = _ii(a, b, c, d, x[i + 0], 6, -198630844); d = _ii(d, a, b, c, x[i + 7], 10, 1126891415); c = _ii(c, d, a, b, x[i + 14], 15, -1416354905); b = _ii(b, c, d, a, x[i + 5], 21, -57434055);
            a = _ii(a, b, c, d, x[i + 12], 6, 1700485571); d = _ii(d, a, b, c, x[i + 3], 10, -1894986606); c = _ii(c, d, a, b, x[i + 10], 15, -1051523); b = _ii(b, c, d, a, x[i + 1], 21, -2054922799);
            a = _ii(a, b, c, d, x[i + 8], 6, 1873313359); d = _ii(d, a, b, c, x[i + 15], 10, -30611744); c = _ii(c, d, a, b, x[i + 6], 15, -1560198380); b = _ii(b, c, d, a, x[i + 13], 21, 1309151649);

            a = (a + oa) | 0; b = (b + ob) | 0; c = (c + oc) | 0; d = (d + od) | 0;
        }
        function toHex(n) {
            let s = '';
            for (let i = 0; i < 4; i++) s += ('0' + (((n >>> (i * 8)) & 255).toString(16))).slice(-2);
            return s;
        }
        return toHex(a) + toHex(b) + toHex(c) + toHex(d);
    }
    const EVENT_NAMES = { inited: 'inited', request: 'request', updateAlert: 'updateAlert' };
    const listeners = new Map();
    // 简易工具：UTF-8 编码与 Base64
    function utf8Encode(str) {
        if (typeof TextEncoder !== 'undefined') return new TextEncoder().encode(String(str));
        str = String(str);
        const out = [];
        for (let i = 0; i < str.length; i++) {
            let c = str.charCodeAt(i);
            if (c < 128) out.push(c);
            else if (c < 2048) { out.push((c >> 6) | 192, (c & 63) | 128); }
            else if ((c & 0xFC00) === 0xD800 && i + 1 < str.length && (str.charCodeAt(i + 1) & 0xFC00) === 0xDC00) {
                c = 0x10000 + ((c & 0x3FF) << 10) + (str.charCodeAt(++i) & 0x3FF);
                out.push((c >> 18) | 240, ((c >> 12) & 63) | 128, ((c >> 6) & 63) | 128, (c & 63) | 128);
            } else { out.push((c >> 12) | 224, ((c >> 6) & 63) | 128, (c & 63) | 128); }
        }
        return new Uint8Array(out);
    }
    function u8ToBase64(u8) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
        let output = '';
        let i = 0;
        while (i < u8.length) {
            const c1 = u8[i++];
            const c2 = i < u8.length ? u8[i++] : NaN;
            const c3 = i < u8.length ? u8[i++] : NaN;
            const e1 = c1 >> 2;
            const e2 = ((c1 & 3) << 4) | (isNaN(c2) ? 0 : (c2 >> 4));
            const e3 = isNaN(c2) ? 64 : (((c2 & 15) << 2) | (isNaN(c3) ? 0 : (c3 >> 6)));
            const e4 = isNaN(c3) ? 64 : (c3 & 63);
            output += chars.charAt(e1) + chars.charAt(e2) + chars.charAt(e3) + chars.charAt(e4);
        }
        return output;
    }

    function base64ToU8(b64) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
        const lookup = new Uint8Array(256);
        for (let i = 0; i < chars.length; i++) lookup[chars.charCodeAt(i)] = i;
        // remove invalid chars
        b64 = String(b64).replace(/[^A-Za-z0-9\+\/\=]/g, '');
        const len = b64.length;
        const placeHolders = b64.endsWith('==') ? 2 : b64.endsWith('=') ? 1 : 0;
        const bytes = new Uint8Array(((len * 3) >> 2) - placeHolders);
        let p = 0;
        for (let i = 0; i < len; i += 4) {
            const enc1 = lookup[b64.charCodeAt(i)];
            const enc2 = lookup[b64.charCodeAt(i + 1)];
            const enc3 = lookup[b64.charCodeAt(i + 2)];
            const enc4 = lookup[b64.charCodeAt(i + 3)];
            const n = (enc1 << 18) | (enc2 << 12) | (enc3 << 6) | enc4;
            if (p < bytes.length) bytes[p++] = (n >> 16) & 0xFF;
            if (p < bytes.length) bytes[p++] = (n >> 8) & 0xFF;
            if (p < bytes.length) bytes[p++] = n & 0xFF;
        }
        return bytes;
    }

    // on(event, handler)
    function on(event, handler) {
        if (typeof handler !== 'function') return;
        if (!listeners.has(event)) listeners.set(event, []);
        listeners.get(event).push(handler);
    }

    // send(event, data)
    function send(event, data) {
        try {
            const payload = JSON.stringify(data == null ? null : data);
            sendMessage('__lx_send__', JSON.stringify([event, payload]));
        } catch (e) { }
    }

    // request(url, options, cb)
    function request(url, options, cb) {
        const fetchOptions = Object.assign({}, options || {});
        if (fetchOptions && fetchOptions.body && typeof fetchOptions.body === 'object' && !(fetchOptions.body instanceof Uint8Array)) {
            try { fetchOptions.body = JSON.stringify(fetchOptions.body); } catch (_) { }
            fetchOptions.headers = fetchOptions.headers || {};
            const h = fetchOptions.headers;
            const key = Object.keys(h).find(k => k.toLowerCase() === 'content-type');
            if (!key) h['content-type'] = 'application/json;charset=UTF-8';
        }
        fetch(url, fetchOptions).then(async resp => {
            let bodyText = '';
            try { bodyText = await resp.text(); } catch (_) { }
            let bodyParsed = bodyText;
            try { bodyParsed = JSON.parse(bodyText); } catch (_) { }
            cb && cb(null, { statusCode: resp.status || 200, headers: {}, body: bodyParsed }, bodyText);
        }).catch(err => { cb && cb(err, null, null); });
        return function cancel() { };
    }

    function __lx_emit_request(arg) {
        const ls = listeners.get(EVENT_NAMES.request) || [];
        const fn = ls.find && typeof ls.find === 'function' ? ls.find(h => typeof h === 'function') : (ls.length ? ls[0] : null);
        if (typeof fn !== 'function') return Promise.reject(new Error('no request listener'));
        try {
            const r = fn(arg);
            if (r && typeof r.then === 'function') return r;
            return Promise.resolve(r);
        } catch (e) { return Promise.reject(e); }
    }

    // 安装到全局
    // 由 Dart 端替换占位符 __HEADER_JSON__
    globalThis.lx = Object.freeze({
        version: '1.0.0',
        env: 'desktop',
        currentScriptInfo: __HEADER_JSON__,
        EVENT_NAMES,
        on,
        send,
        request,
        utils: {
            buffer: {
                from: function (input, enc) {
                    if (!enc || enc.toLowerCase() === 'utf-8' || enc.toLowerCase() === 'utf8') return utf8Encode(input);
                    return utf8Encode(String(input));
                },
                bufToString: function (buf, format) {
                    if (format && format.toLowerCase() === 'base64') {
                        if (buf instanceof Uint8Array) return u8ToBase64(buf);
                        try { return u8ToBase64(utf8Encode(String(buf))); } catch (_) { return String(buf); }
                    }
                    try { return String(buf); } catch (_) { return ''; }
                },
            },
            crypto: {
                md5: md5,
                aesEncrypt: function (buffer, mode, key, iv) {
                    // 返回 Promise，通过 Dart 侧执行 AES
                    return new Promise((resolve, reject) => {
                        try {
                            const id = Math.random().toString(36).slice(2);
                            if (!globalThis.__lx_crypto_pending) globalThis.__lx_crypto_pending = new Map();
                            globalThis.__lx_crypto_pending.set(id, { resolve, reject });
                            // 统一转 Uint8Array
                            let u8;
                            if (buffer instanceof Uint8Array) u8 = buffer; else u8 = utf8Encode(String(buffer));
                            const payload = {
                                id,
                                op: 'aesEncrypt',
                                mode: String(mode || 'cbc').toLowerCase(),
                                key: key == null ? '' : String(key),
                                iv: iv == null ? '' : String(iv),
                                data: u8ToBase64(u8),
                            };
                            sendMessage('__lx_crypto__', JSON.stringify(payload));
                        } catch (e) { reject(e); }
                    });
                },
            },
            zlib: {}
        },
    });
    Object.defineProperty(globalThis, '__lx_emit_request', { value: __lx_emit_request, enumerable: false });
    Object.defineProperty(globalThis, '__lx_crypto_resolve', {
        value: function (id, base64Data) {
            const map = globalThis.__lx_crypto_pending; if (!map) return;
            const h = map.get(id); if (!h) return;
            map.delete(id);
            try { h.resolve(base64ToU8(base64Data)); } catch (e) { h.reject(e); }
        }, enumerable: false
    });
    Object.defineProperty(globalThis, '__lx_crypto_reject', {
        value: function (id, message) {
            const map = globalThis.__lx_crypto_pending; if (!map) return;
            const h = map.get(id); if (!h) return;
            map.delete(id);
            h.reject(new Error(String(message || 'aes error')));
        }, enumerable: false
    });
})();
