import 'package:flutter/material.dart';

/// 任务状态
enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

/// 任务信息
class TaskInfo {
  final String id;
  final String description;
  final TaskStatus status;
  final double progress;
  final String? error;
  final DateTime startTime;
  final DateTime? endTime;

  TaskInfo({
    required this.id,
    required this.description,
    required this.status,
    this.progress = 0.0,
    this.error,
    required this.startTime,
    this.endTime,
  });

  Duration? get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get statusText {
    switch (status) {
      case TaskStatus.pending:
        return '等待中';
      case TaskStatus.running:
        return '运行中';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '失败';
      case TaskStatus.cancelled:
        return '已取消';
    }
  }

  Color get statusColor {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.running:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return Colors.red;
      case TaskStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.running:
        return Icons.play_arrow;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.failed:
        return Icons.error;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }
}

/// 任务列表组件
class TaskListView extends StatelessWidget {
  final List<TaskInfo> tasks;
  final void Function(String taskId)? onCancel;
  final void Function(String taskId)? onRetry;
  final bool showEmpty;

  const TaskListView({
    super.key,
    required this.tasks,
    this.onCancel,
    this.onRetry,
    this.showEmpty = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty && showEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _TaskCard(
          task: tasks[index],
          onCancel: onCancel,
          onRetry: onRetry,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '没有运行中的任务',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有任务已完成',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务卡片
class _TaskCard extends StatelessWidget {
  final TaskInfo task;
  final void Function(String taskId)? onCancel;
  final void Function(String taskId)? onRetry;

  const _TaskCard({
    required this.task,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.statusColor.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: task.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (task.status == TaskStatus.running && onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onCancel?.call(task.id),
                    tooltip: '取消',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),

            // 进度条
            if (task.status == TaskStatus.running) ...[
              const SizedBox(height: 8),
              _buildProgressBar(),
              const SizedBox(height: 4),
              _buildProgressText(),
            ],

            // 错误信息
            if (task.status == TaskStatus.failed && task.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.error!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onRetry?.call(task.id),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重试'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ],

            // 时间信息
            if (task.duration != null) ...[
              const SizedBox(height: 8),
              _buildDurationInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (task.status == TaskStatus.running) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(task.statusColor),
        ),
      );
    }

    return Icon(
      task.statusIcon,
      color: task.statusColor,
      size: 20,
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: task.progress > 0 ? task.progress : null,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation(task.statusColor),
        minHeight: 6,
      ),
    );
  }

  Widget _buildProgressText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          task.progress > 0 ? '${(task.progress * 100).toInt()}%' : '处理中...',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        if (task.duration != null)
          Text(
            _formatDuration(task.duration!),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  Widget _buildDurationInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 12,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 4),
          Text(
            '用时: ${_formatDuration(task.duration!)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    if (task.status == TaskStatus.running) {
      return Colors.blue.shade50;
    } else if (task.status == TaskStatus.failed) {
      return Colors.red.shade50;
    } else if (task.status == TaskStatus.completed) {
      return Colors.green.shade50;
    }
    return Colors.grey.shade50;
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
