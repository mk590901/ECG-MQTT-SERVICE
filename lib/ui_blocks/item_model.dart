// Data model for item
import 'package:gui_model/widget/graph_widget.dart';

class Item {
  final String id;
  final String title;
  final String subtitle;
  final GraphWidget graphWidget;

  Item({required this.id, required this.title, required this.subtitle, required this.graphWidget});
}
