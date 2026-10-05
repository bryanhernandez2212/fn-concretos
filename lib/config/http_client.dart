import 'dart:convert';

import 'package:http/http.dart' as http;

export 'package:http/http.dart' hide get, post, put, patch, delete, head, read, readBytes;

/// Drop-in for `package:http`'s top-level functions, imported `as http` by
/// every service. Those top-level functions open (and close) a fresh client
/// per call, so every request paid for a new TCP + TLS handshake. One shared
/// client keeps connections alive and reuses them across requests and
/// services. Never closed: it lives as long as the app.
final _client = http.Client();

Future<http.Response> get(Uri url, {Map<String, String>? headers}) => _client.get(url, headers: headers);

Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.put(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.patch(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _client.delete(url, headers: headers, body: body, encoding: encoding);
