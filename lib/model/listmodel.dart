class MyList {
  final String listTask;
  final bool isDone;

  const MyList({
    required this.listTask,
    required this.isDone,
  });

  factory MyList.fromJson(Map<String, dynamic> json) => MyList(
        listTask: json['listTask'],
        isDone: json['isDone'],
      );

  Map<String, dynamic> toJson() => {'listTask': listTask, 'isDine': isDone};
}
