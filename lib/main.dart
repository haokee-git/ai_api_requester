import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI API 请求器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: 'PingFang SC',
        fontFamilyFallback: const ['Microsoft YaHei', 'SimHei'],
        useMaterial3: true,
      ),
      localizationsDelegates: const [FlutterQuillLocalizations.delegate],
      home: const AIApiRequester(),
    );
  }
}

class AIApiRequester extends StatefulWidget {
  const AIApiRequester({super.key});

  @override
  State<AIApiRequester> createState() => _AIApiRequesterState();
}

class _AIApiRequesterState extends State<AIApiRequester> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelIdController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final QuillController _quillController = QuillController.basic();

  @override
  void initState() {
    super.initState();
    _quillController.addListener(() {
      _promptController.text = _quillController.document.toPlainText();
    });
  }

  String _output = '';
  bool _isLoading = false;
  bool _autoCompleteUrl = true;
  String _protocolOption = 'none'; // 'http', 'https', 'none'
  StreamSubscription? _streamSubscription;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelIdController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  String _getCompleteUrl() {
    String baseUrl = _baseUrlController.text.trim();

    // 自动补全协议
    if (_protocolOption != 'none' && baseUrl.isNotEmpty) {
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = '$_protocolOption://$baseUrl';
      }
    }

    // 自动补全路径
    if (_autoCompleteUrl && baseUrl.isNotEmpty) {
      if (!baseUrl.endsWith('/v1/chat/completions')) {
        if (baseUrl.endsWith('/')) {
          baseUrl += 'v1/chat/completions';
        } else {
          baseUrl += '/v1/chat/completions';
        }
      }
    }
    return baseUrl;
  }

  void _stopRequest() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _sendRequest() async {
    if (_baseUrlController.text.trim().isEmpty ||
        _apiKeyController.text.trim().isEmpty ||
        _modelIdController.text.trim().isEmpty ||
        _promptController.text.trim().isEmpty) {
      setState(() {
        _output = '请填写所有必需字段';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _output = '';
    });

    try {
      final url = _getCompleteUrl();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_apiKeyController.text.trim()}',
      };

      final body = json.encode({
        'model': _modelIdController.text.trim(),
        'messages': [
          {'role': 'user', 'content': _promptController.text.trim()},
        ],
        'stream': true,
      });

      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.body = body;

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        String accumulatedContent = '';

        _streamSubscription = streamedResponse.stream
            .transform(utf8.decoder)
            .listen(
              (String chunk) {
                if (!_isLoading) return; // 如果已停止，不处理数据

                final lines = chunk.split('\n');
                for (String line in lines) {
                  if (line.startsWith('data: ')) {
                    final data = line.substring(6);
                    if (data.trim() == '[DONE]') {
                      _stopRequest();
                      return;
                    }

                    try {
                      final jsonData = json.decode(data);
                      final content =
                          jsonData['choices']?[0]?['delta']?['content'];
                      if (content != null) {
                        accumulatedContent += content;
                        setState(() {
                          _output = accumulatedContent;
                        });
                      }
                    } catch (e) {
                      // 忽略解析错误，继续处理下一行
                    }
                  }
                }
              },
              onDone: () {
                setState(() {
                  _isLoading = false;
                });
              },
              onError: (error) {
                setState(() {
                  _isLoading = false;
                  _output = '流处理错误: $error';
                });
              },
            );
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        setState(() {
          _isLoading = false;
          _output = '请求失败 (${streamedResponse.statusCode}): $errorBody';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output = '请求错误: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI API 请求器',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Base URL 输入框
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _baseUrlController,
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        labelStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: '例如: https://api.openai.com',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: _baseUrlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _baseUrlController.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {}); // 触发重建以更新清空按钮显示状态
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 自动补全选项
                  Row(
                    children: [
                      Checkbox(
                        value: _autoCompleteUrl,
                        onChanged: (value) {
                          setState(() {
                            _autoCompleteUrl = value ?? true;
                          });
                        },
                      ),
                      const Text('自动补全 /v1/chat/completions'),
                      const SizedBox(width: 20),
                      const Text('协议补全:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _protocolOption,
                        onChanged: (String? newValue) {
                          setState(() {
                            _protocolOption = newValue ?? 'https';
                          });
                        },
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'https',
                            child: Text('HTTPS'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'http',
                            child: Text('HTTP'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'none',
                            child: Text('不补充'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // URL 预览
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '实际请求 URL:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCompleteUrl().isEmpty
                              ? '请输入 Base URL'
                              : _getCompleteUrl(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getCompleteUrl().isEmpty
                                ? Colors.grey
                                : Colors.blue[800],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // API Key 输入框
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: '请输入 API Key',
                        labelStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      obscureText: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 模型ID 输入框
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _modelIdController,
                      decoration: InputDecoration(
                        labelText: 'Model ID',
                        hintText: '请输入模型 ID',
                        labelStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prompt 输入框和发送按钮
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          height: 200,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: QuillSimpleToolbar(
                                  controller: _quillController,
                                  config: const QuillSimpleToolbarConfig(
                                    showBoldButton: true,
                                    showItalicButton: true,
                                    showUnderLineButton: true,
                                    showStrikeThrough: true,
                                    showCodeBlock: true,
                                    showListNumbers: true,
                                    showListBullets: true,
                                    showHeaderStyle: true,
                                    showQuote: true,
                                    showLink: true,
                                    multiRowsDisplay: false,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: QuillEditor.basic(
                                    controller: _quillController,
                                    config: QuillEditorConfig(
                                      placeholder: 'Prompt (支持富文本编辑)',
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFEF4444),
                                    Color(0xFFDC2626),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isLoading
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF3B82F6))
                                      .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isLoading ? _stopRequest : _sendRequest,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  _isLoading ? Icons.stop : Icons.send,
                                  key: ValueKey(_isLoading),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 输出区域
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 输出标题栏
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '输出',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (_output.isNotEmpty)
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () async {
                                        await html.window.navigator.clipboard
                                            ?.writeText(_output);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('已复制到剪贴板'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.copy,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '复制',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 输出内容区域
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 200,
                            maxHeight: _output.isEmpty ? 200 : double.infinity,
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          child: _output.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 48,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        '输出将在这里显示...',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : MarkdownBody(
                                  data: _output,
                                  selectable: true,
                                  onTapLink: (text, href, title) {
                                    if (href != null) {
                                      // 在新标签页打开链接
                                      html.window.open(href, '_blank');
                                    }
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
