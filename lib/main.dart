import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:native_pdf_renderer/native_pdf_renderer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter PDF Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

enum PDFPageStatus {
  init,
  loading,
  loadingMore,
  loaded,
}

class PDFPageState {
  const PDFPageState({
    required this.status,
    required this.pages,
    required this.currentPage,
  });

  final PDFPageStatus status;
  final List<Uint8List?> pages;
  final int currentPage;

  bool get isBusy => status == PDFPageStatus.loading || status == PDFPageStatus.loadingMore;

  bool get isLoadingMore => status == PDFPageStatus.loadingMore;

  factory PDFPageState.init() {
    return const PDFPageState(
      status: PDFPageStatus.init,
      pages: [],
      currentPage: 1,
    );
  }

  PDFPageState update({
    PDFPageStatus? status,
    List<Uint8List?>? pages,
    int? currentPage,
  }) {
    return PDFPageState(
      status: status ?? this.status,
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PDFPageState && other.status == status && other.currentPage == currentPage && listEquals(other.pages, pages);
  }

  @override
  int get hashCode => status.hashCode ^ currentPage.hashCode ^ pages.hashCode;
}

class _MyHomePageState extends State<MyHomePage> {
  final pdfDoc = Completer<PdfDocument>();
  final pdfLoadStatus = ValueNotifier<PDFPageState>(PDFPageState.init());
  final pdfScrollController = ScrollController();

  static const String pdfFile = 'assets/test.pdf';

  PDFPageState get state => pdfLoadStatus.value;

  @override
  void initState() {
    super.initState();
    PdfDocument.openAsset(pdfFile).then(pdfDoc.complete);
    pdfScrollController.addListener(fetchMorePdfPage);
    loadPdfPages();
  }

  @override
  void dispose() {
    pdfLoadStatus.dispose();
    pdfScrollController.dispose();
    super.dispose();
  }

  Future<void> loadPdfPages({bool more = false}) async {
    if (state.isBusy) return;

    pdfLoadStatus.value = state.update(status: more ? PDFPageStatus.loadingMore : PDFPageStatus.loading);

    final pdfDoc = await this.pdfDoc.future;
    final nextPage = more ? state.currentPage + 1 : 1;

    final PdfPage nextPdf = await pdfDoc.getPage(nextPage);
    final PdfPageImage? nextPdfImage = await nextPdf.render(width: 1080, height: 1920);
    await nextPdf.close();

    pdfLoadStatus.value = state.update(
      status: PDFPageStatus.loaded,
      currentPage: nextPage,
      pages: [
        ...state.pages,
        nextPdfImage?.bytes,
      ],
    );
  }

  void fetchMorePdfPage() {
    if (state.isBusy) return;

    if (pdfScrollController.offset >= pdfScrollController.position.maxScrollExtent - 80 &&
        pdfScrollController.position.userScrollDirection == ScrollDirection.reverse &&
        !state.isBusy) {
      loadPdfPages(more: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer Test'),
      ),
      body: ValueListenableBuilder<PDFPageState>(
        valueListenable: pdfLoadStatus,
        builder: (context, currentState, child) {
          if (currentState.status == PDFPageStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return CustomScrollView(
            controller: pdfScrollController,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) {
                    final currentPageImageByte = currentState.pages[index];
                    if (currentPageImageByte != null) {
                      return Image.memory(currentPageImageByte);
                    }
                    return const SizedBox(
                      width: 1080,
                      height: 1920,
                      child: Center(
                        child: Icon(
                          Icons.error,
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                  childCount: currentState.pages.length,
                ),
              ),
              SliverToBoxAdapter(
                child: TextButton(
                  onPressed: currentState.isLoadingMore ? null : () => loadPdfPages(more: true),
                  child: currentState.isLoadingMore ? const CircularProgressIndicator() : Text('Load more'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}