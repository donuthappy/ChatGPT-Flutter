import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> listMessages = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            child: Container(
              height: 50,
              color: Colors.grey.shade300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text(
                      'My Chat',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: InkWell(
                      onTap: () {},
                      child: const Icon(Icons.more_vert_outlined),
                    ),
                  )
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 60),
            child: ListView(
              controller: _scrollController,
              children: [
                for (var i = 0; i < listMessages.length; i++) ...[
                  buildContent(listMessages[i]),
                ]
              ],
            ),
          ),
          buildInput(),
        ],
      ),
    );
  }

  buildContent(item) {
    return Align(
      alignment:
          item['role'] == 0 ? Alignment.bottomRight : Alignment.bottomLeft,
      child: Padding(
        padding: item['role'] == 1
            ? const EdgeInsets.only(bottom: 10, left: 20, right: 200)
            : const EdgeInsets.only(bottom: 10, left: 200, right: 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: item['role'] == 1
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
            color: (item['role'] == 0
                ? Colors.green.shade300
                : Colors.grey.shade300),
          ),
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Text(
                item['content'],
                style: TextStyle(
                  fontSize: 14,
                  color: item['role'] == 1 ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  buildInput() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.only(left: 25, right: 10),
        decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: const BorderRadius.all(Radius.circular(35))),
        child: TextField(
          controller: _inputController,
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            hoverColor: Colors.grey.shade300,
            hintText: 'Type your message...',
            hintStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            suffixIcon: InkWell(
              onTap: () {
                sendMessage();
              },
              child: const Icon(Icons.send_outlined),
            ),
          ),
          maxLines: 4,
          minLines: 1,
        ),
      ),
    );
  }

  sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _inputController.clear();

      setState(() {
        listMessages.add({"role": 0, 'content': text});
        listMessages.add({"role": 1, 'content': '...'});
      });

      _scrollToLastMessage();

      String? strAssistantContent = await sendToChatGPT(text);

      var result = await sendQueryToDialogflow(text);
      print(result);

      if (strAssistantContent != null) {
        setState(() {
          listMessages.removeAt(listMessages.length - 1);
          listMessages.add({"role": 1, 'content': strAssistantContent});
        });
      }

      _scrollToLastMessage();
    }
  }

  Future<String?> sendToChatGPT(String message) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    const apiKey = "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";
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = json.encode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': 'You are a helpful assistant.'},
        {'role': 'user', 'content': message},
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String strContent = data['choices'][0]['message']['content'];
        return strContent;
      } else {
        print('Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>> sendQueryToDialogflow(String query) async {
    String strSessionId = generateRandomSessionId();
    var url =
        'https://dialogflow.googleapis.com/v2/projects/of-chatbot-pokh/agent/sessions/$strSessionId:detectIntent';
    var apiKey = 'ChatGPT-API-KEY';
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    var body = {
      'queryInput': {
        'text': {
          'text': query,
          'languageCode': 'en', // Language code for the user's query
        },
      },
    };

    print(url);
    print(headers);
    print(body);

    var response = await http.post(Uri.parse(url),
        headers: headers, body: jsonEncode(body));

    if (response.statusCode == 200) {
      // API call successful, return the JSON response
      return jsonDecode(response.body);
    } else {
      // Handle error if the API call fails
      throw Exception('Failed to get response from Dialogflow API');
    }
  }

  String generateRandomSessionId() {
    // You can use any method to generate a unique session ID, such as UUID or timestamp
    // For simplicity, we'll use the current timestamp here
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  //scroll to last message
  void _scrollToLastMessage() {
    final double height = _scrollController.position.maxScrollExtent;
    // final double lastMessageHeight =
    //     _scrollController.position.viewportDimension;
    _scrollController.animateTo(
      height,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }
}
