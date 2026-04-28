#!/usr/bin/env python3
"""
Send a /beambot_execution goal and print feedback + result.

Invoked by send-goal.sh. Takes one argument: path to a goal.json file
whose contents become the MTCExecution.Goal's full_json field (as a
single string, not a parsed object).

Using rclpy's ActionClient directly avoids the shell-quoting hell that
would otherwise ensue trying to pass a JSON blob through
`ros2 action send_goal`'s YAML parser.
"""
from __future__ import annotations

import sys
import time

import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node

from beambot_interfaces.action import MTCExecution


class GoalSender(Node):
    def __init__(self, goal_json: str) -> None:
        super().__init__('xsub_poc_goal_sender')
        self._client = ActionClient(self, MTCExecution, '/beambot_execution')
        self._goal_json = goal_json
        self._result_status: int | None = None
        self._result_msg = None
        self._done = False

    def send_and_wait(self, discovery_timeout: float = 20.0) -> int:
        self.get_logger().info(
            f'waiting for /beambot_execution action server '
            f'(timeout {discovery_timeout}s)...'
        )
        if not self._client.wait_for_server(timeout_sec=discovery_timeout):
            self.get_logger().error(
                'action server not available -- discovery failed '
                '(most likely the firewall blocked DDS discovery or data)'
            )
            return 2

        goal = MTCExecution.Goal()
        goal.full_json = self._goal_json
        self.get_logger().info('sending goal...')
        send_future = self._client.send_goal_async(
            goal, feedback_callback=self._on_feedback
        )
        rclpy.spin_until_future_complete(self, send_future)
        handle = send_future.result()
        if not handle.accepted:
            self.get_logger().error('goal rejected by server')
            return 3

        self.get_logger().info(f'goal accepted (id=0x{handle.goal_id.uuid.tobytes().hex()[:16]}...)')
        result_future = handle.get_result_async()
        rclpy.spin_until_future_complete(self, result_future)
        self._result_msg = result_future.result().result
        self._result_status = result_future.result().status
        return 0

    def _on_feedback(self, feedback_msg) -> None:
        fb = feedback_msg.feedback
        self.get_logger().info(
            f'feedback: step={fb.current_step} '
            f'action={fb.current_action!r} '
            f'progress={fb.progress_percentage:.0f}% '
            f'gripper={fb.current_gripper!r} '
            f'msg={fb.status_message!r}'
        )


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: _send_goal.py <goal-json-path>', file=sys.stderr)
        return 2

    with open(sys.argv[1]) as fp:
        goal_json = fp.read()

    rclpy.init()
    node = GoalSender(goal_json)
    try:
        status = node.send_and_wait()
        if status != 0:
            return status

        # ActionClient status codes: 4 = SUCCEEDED, 5 = CANCELED, 6 = ABORTED
        status_names = {4: 'SUCCEEDED', 5: 'CANCELED', 6: 'ABORTED'}
        status_name = status_names.get(node._result_status, f'UNKNOWN({node._result_status})')
        print('')
        print('=' * 60)
        print(f'RESULT STATUS: {status_name}')
        print(f'  success:        {node._result_msg.success}')
        print(f'  error_message:  {node._result_msg.error_message or "(none)"}')
        print(f'  completed:      {node._result_msg.completed_steps}/{node._result_msg.total_steps} steps')
        print('=' * 60)
        return 0 if node._result_msg.success else 1
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    sys.exit(main())
