// Agent 步骤进度展示组件
//
// 展示任务分解、执行进度、重试状态

import 'package:flutter/material.dart';
import '../providers/app_state.dart';

/// Agent 步骤进度 Widget
class AgentProgressWidget extends StatelessWidget {
  final List<AgentStep> steps;
  final String? currentMessage;

  const AgentProgressWidget({
    super.key,
    required this.steps,
    this.currentMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isRunning = steps.any((s) => s.status == 'running' || s.status == 'retrying');
    final isAllDone = steps.every((s) => s.status == 'completed' || s.status == 'failed');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning
              ? theme.colorScheme.primary.withOpacity(0.3)
              : isAllDone
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (isRunning)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else if (isAllDone)
                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade700)
                else
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  isRunning
                      ? '执行中 ${_progressText()}'
                      : isAllDone
                          ? '已完成 ${_progressText()}'
                          : '准备中 ${_progressText()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // 步骤列表
          ...steps.map((step) => _buildStep(context, step)),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, AgentStep step) {
    final theme = Theme.of(context);
    final isActive = step.status == 'running';
    final isCompleted = step.status == 'completed';
    final isFailed = step.status == 'failed';
    final isRetrying = step.status == 'retrying';

    Color? iconColor;
    IconData? statusIcon;
    if (isCompleted) {
      iconColor = Colors.green.shade600;
      statusIcon = Icons.check_circle_outline;
    } else if (isFailed) {
      iconColor = Colors.red.shade400;
      statusIcon = Icons.error_outline;
    } else if (isRetrying) {
      iconColor = Colors.orange.shade400;
      statusIcon = Icons.refresh;
    } else if (isActive) {
      iconColor = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态图标
          SizedBox(
            width: 18,
            height: 18,
            child: isActive || isRetrying
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  )
                : statusIcon != null
                    ? Icon(statusIcon, size: 16, color: iconColor)
                    : Icon(Icons.circle_outlined, size: 16, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 8),

          // 步骤内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive
                        ? theme.colorScheme.primary
                        : isFailed
                            ? Colors.red.shade700
                            : isCompleted
                                ? theme.colorScheme.onSurface.withOpacity(0.8)
                                : Colors.grey,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    decoration: isCompleted ? TextDecoration.none : null,
                  ),
                ),

                // 结果摘要（完成时显示）
                if (isCompleted && step.result != null && step.result!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.result!.length > 100
                        ? '${step.result!.substring(0, 100)}...'
                        : step.result!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // 错误信息
                if (isFailed && step.error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.error!.length > 80
                        ? '${step.error!.substring(0, 80)}...'
                        : step.error!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // 重试标记
                if (isRetrying) ...[
                  const SizedBox(height: 2),
                  Text(
                    '重试中 (${step.retryCount})...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _progressText() {
    final completed = steps.where((s) => s.status == 'completed').length;
    return '($completed/${steps.length})';
  }
}
