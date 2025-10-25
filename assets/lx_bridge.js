function registConsole() {
    const c = globalThis.console;
    c.assert = function () { };
    c.clear = function () { };
    c.context = function () { };
    c.count = function () { };
    c.countReset = function () { };
    c.createTask = function () { };
    c.debug = function () { };
    c.dir = function () { };
    c.dirxml = function () { };
    c.group = function () { };
    c.groupCollapsed = function () { };
    c.groupEnd = function () { };
    c.info = function () { };
    c.profile = function () { };
    c.profileEnd = function () { };
    c.table = function () { };
    c.time = function () { };
    c.timeEnd = function () { };
    c.timeLog = function () { };
    c.timeStamp = function () { };
    c.trace = function () { };
}

function createRandomUint8Array(length) {
    const array = new Uint8Array(length);
    for (let i = 0; i < length; i++) {
        array[i] = Math.floor(Math.random() * 256);
    }
    return array;
}

function bufferToUtf8String(buffer, start = 0, end = buffer.length) {
    if (start < 0) start = 0;
    if (end > buffer.length) end = buffer.length;
    if (start >= end) return '';

    let result = '';
    let i = start;

    while (i < end) {
        const byte = buffer[i];

        if (byte < 0x80) {
            // 单字节字符 (0xxxxxxx)
            result += String.fromCharCode(byte);
            i += 1;
        } else if (byte < 0xE0) {
            // 双字节字符 (110xxxxx 10xxxxxx)
            if (i + 1 >= end) {
                // 不完整的序列，使用替换字符
                result += '�';
                break;
            }

            const secondByte = buffer[i + 1];
            // 检查第二个字节是否有效
            if ((secondByte & 0xC0) !== 0x80) {
                result += '�';
                i += 1;
                continue;
            }

            const codePoint = ((byte & 0x1F) << 6) | (secondByte & 0x3F);
            result += String.fromCharCode(codePoint);
            i += 2;
        } else if (byte < 0xF0) {
            // 三字节字符 (1110xxxx 10xxxxxx 10xxxxxx)
            if (i + 2 >= end) {
                // 不完整的序列，使用替换字符
                result += '�';
                break;
            }

            const secondByte = buffer[i + 1];
            const thirdByte = buffer[i + 2];

            // 检查后续字节是否有效
            if ((secondByte & 0xC0) !== 0x80 || (thirdByte & 0xC0) !== 0x80) {
                result += '�';
                i += 1;
                continue;
            }

            const codePoint = ((byte & 0x0F) << 12) |
                ((secondByte & 0x3F) << 6) |
                (thirdByte & 0x3F);
            result += String.fromCharCode(codePoint);
            i += 3;
        } else if (byte < 0xF8) {
            // 四字节字符 (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
            if (i + 3 >= end) {
                // 不完整的序列，使用替换字符
                result += '�';
                break;
            }

            const secondByte = buffer[i + 1];
            const thirdByte = buffer[i + 2];
            const fourthByte = buffer[i + 3];

            // 检查后续字节是否有效
            if ((secondByte & 0xC0) !== 0x80 ||
                (thirdByte & 0xC0) !== 0x80 ||
                (fourthByte & 0xC0) !== 0x80) {
                result += '�';
                i += 1;
                continue;
            }

            const codePoint = ((byte & 0x07) << 18) |
                ((secondByte & 0x3F) << 12) |
                ((thirdByte & 0x3F) << 6) |
                (fourthByte & 0x3F);

            // JavaScript 使用 UTF-16，需要代理对表示大于 0xFFFF 的字符
            if (codePoint > 0xFFFF) {
                // 转换为代理对
                const highSurrogate = 0xD800 + (((codePoint - 0x10000) >> 10) & 0x3FF);
                const lowSurrogate = 0xDC00 + ((codePoint - 0x10000) & 0x3FF);
                result += String.fromCharCode(highSurrogate, lowSurrogate);
            } else {
                result += String.fromCharCode(codePoint);
            }
            i += 4;
        } else {
            // 无效的 UTF-8 起始字节
            result += '�';
            i += 1;
        }
    }

    return result;
}

function aesEncrypt(data, algorithm, key, iv = null) {

    const [cipher, keySize, mode] = algorithm.split('-');

    if (cipher !== 'aes' || keySize !== '128') {
        throw new Error('只支持 aes-128-cbc 和 aes-128-ecb 算法');
    }

    // 检查 IV 需求
    if (mode === 'cbc') {
        if (!iv || iv.length !== 16) {
            throw new Error('CBC 模式需要 16 字节的 IV');
        }
    } else if (mode !== 'ecb') {
        throw new Error('不支持的加密模式: ' + mode);
    }

    // 将 Uint8Array 转换为 CryptoJS 的 WordArray
    const wordArrayData = CryptoJS.lib.WordArray.create(data);
    const keyWordArray = CryptoJS.lib.WordArray.create(key);
    const ivWordArray = (mode === 'cbc' && iv) ? CryptoJS.lib.WordArray.create(iv) : undefined;

    // 配置加密选项
    const options = {
        mode: mode === 'cbc' ? CryptoJS.mode.CBC : CryptoJS.mode.ECB,
        padding: CryptoJS.pad.Pkcs7
    };

    if (ivWordArray) {
        options.iv = ivWordArray;
    }

    // 执行加密
    const encrypted = CryptoJS.AES.encrypt(wordArrayData, keyWordArray, options);

    // 将加密结果转换回 Uint8Array
    const ciphertextWordArray = encrypted.ciphertext;
    const result = new Uint8Array(ciphertextWordArray.sigBytes);

    for (let i = 0; i < ciphertextWordArray.sigBytes; i++) {
        result[i] = (ciphertextWordArray.words[i >>> 2] >>> (24 - (i % 4) * 8)) & 0xff;
    }

    return result;
}

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

function bufferFromUtf8String(input, enc) {
    if (!enc || enc.toLowerCase() === 'utf-8' || enc.toLowerCase() === 'utf8') return utf8Encode(input);
    return utf8Encode(String(input));
}


(function () {
    registConsole();
    const EVENT_NAMES = { inited: 'inited', request: 'request', updateAlert: 'updateAlert' };
    const listeners = new Map();

    // on(event, handler)
    function on(event, handler) {

        console.log('lx_bridge on:', event);
        if (typeof handler !== 'function') return;
        if (!listeners.has(event)) listeners.set(event, []);
        listeners.get(event).push(handler);
    }

    // send(event, data)
    function send(event, data) {
        console.log('lx_bridge send:', event);
        try {
            const payload = JSON.stringify(data == null ? null : data);
            sendMessage('__lx_send__', JSON.stringify([event, payload]));
        } catch (e) { }
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
        version: '2.0.0',
        env: 'desktop',
        currentScriptInfo: __HEADER_JSON__,
        EVENT_NAMES,
        on,
        send,
        request: function request(url, { method = 'get', timeout, headers, body, form, formData }, cb) {
            let xhr = new XMLHttpRequest();
            Object.keys(headers || {}).forEach(key => {
                xhr.setRequestHeader(key, headers[key]);
            });
            xhr.open(method.toUpperCase(), url);
            xhr.timeout = timeout || 8000;
            xhr.send(body || form || formData);
            xhr.onload = function () {
                const resp = {
                    statusCode: xhr.status,
                    statusMessage: xhr.statusText,
                    bytes: xhr.responseText.length,
                    headers: headers,
                    raw: bufferFromUtf8String(xhr.responseText),
                    body: JSON.parse(xhr.responseText)
                };
                try {
                    cb(null, resp, xhr.responseText);
                } catch (e) {
                    Object.keys(e).forEach(key => {
                        console.log(`${key}: ${e[key]}`);
                    });
                    console.log("error")
                }
                console.log("cbf")
            };

            xhr.onerror = function () {
                console.log("error2")
                cb && cb(new Error(""), null, null);
            };
            return function cancel() { xhr.abort(); };
        },
        utils: {
            buffer: {
                from: bufferFromUtf8String,
                bufToString: bufferToUtf8String
            },
            crypto: {
                md5: function (input) {
                    return globalThis.CryptoJS.MD5(input).toString();
                },
                aesEncrypt: aesEncrypt,
                randomBytes: createRandomUint8Array
            },
            zlib: {}
        },
    });

    Object.defineProperty(globalThis, '__lx_emit_request', { value: __lx_emit_request, enumerable: false });
})();
