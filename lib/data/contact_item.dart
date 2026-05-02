import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactItem {
  final String title;
  final FaIconData icon;
  final String url;

  ContactItem({required this.title, required this.icon, required this.url});

  static final List<ContactItem> contactItems = [
    ContactItem(
      title: "Discord 公車交流群",
      icon: FontAwesomeIcons.discord,
      url: "https://tybusstation.github.io/discord",
    ),
    ContactItem(
      title: "Linktree",
      icon: FontAwesomeIcons.link,
      url: "https://tybusstation.github.io",
    ),
    ContactItem(
      title: "Instagram",
      icon: FontAwesomeIcons.instagram,
      url: "https://www.instagram.com/myster.bus/",
    ),
    ContactItem(
      title: "GitHub",
      icon: FontAwesomeIcons.github,
      url: "https://github.com/TYBusStation",
    ),
  ];
}
