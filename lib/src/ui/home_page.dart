import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../models/app_config.dart';
import 'editable_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late EditableConfig _editable;
  bool _dirty = false;
  int _lastSyncedRevision = 0;

  @override
  void initState() {
    super.initState();
    _editable = EditableConfig.fromConfig(widget.controller.state.config);
    _lastSyncedRevision = widget.controller.state.revision;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final snapshot = widget.controller.state;
    if (!_dirty && snapshot.revision != _lastSyncedRevision) {
      setState(() {
        _editable = EditableConfig.fromConfig(snapshot.config);
        _lastSyncedRevision = snapshot.revision;
      });
      return;
    }

    setState(() {
      _lastSyncedRevision = snapshot.revision;
    });
  }

  void _markDirty() {
    setState(() {
      _dirty = true;
    });
  }

  Future<void> _pickDesktopFolder() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null || folder.isEmpty) {
      return;
    }
    setState(() {
      _editable.desktopPath = folder;
      _dirty = true;
    });
  }

  Future<void> _pickRuleTarget(int index) async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null || folder.isEmpty) {
      return;
    }
    setState(() {
      _editable.rules[index].targetFolder = folder;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.state;

    return Scaffold(
      backgroundColor: const Color(0xFF121417),
      appBar: AppBar(
        title: const Text('Desktop Sorter'),
        actions: [
          TextButton.icon(
            onPressed: () => widget.controller.hideToTray(),
            icon: const Icon(Icons.visibility_off),
            label: const Text('Hide to tray'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _badge(
                  snapshot.monitoringActive ? 'Monitoring active' : 'Monitoring paused',
                  snapshot.monitoringActive ? const Color(0xFF2F9F5A) : const Color(0xFFB08435),
                ),
                _badge(
                  snapshot.trayAvailable ? 'Tray ready' : 'Tray unavailable',
                  snapshot.trayAvailable ? const Color(0xFF4F8CCF) : const Color(0xFF9E4A4A),
                ),
                _badge(
                  snapshot.autostartActive ? 'Autostart enabled' : 'Autostart disabled',
                  snapshot.autostartActive ? const Color(0xFF5E87D9) : const Color(0xFF777777),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Config: ${snapshot.configPath}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.statusLine,
              style: const TextStyle(color: Color(0xFFAED4FF)),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'General',
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 160,
                        child: Text('Desktop folder'),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: _editable.desktopPath,
                          onChanged: (value) {
                            _editable.desktopPath = value;
                            _markDirty();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _pickDesktopFolder,
                        child: const Text('Browse'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        width: 160,
                        child: Text('Minimum file age (sec)'),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          initialValue: _editable.minFileAgeSeconds.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _editable.minFileAgeSeconds = int.tryParse(value) ?? 0;
                            _markDirty();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _editable.monitoringEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable background monitoring'),
                    onChanged: (value) {
                      setState(() {
                        _editable.monitoringEnabled = value;
                        _dirty = true;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _editable.pauseWhenFullscreen,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pause monitoring while fullscreen app is running'),
                    onChanged: (value) {
                      setState(() {
                        _editable.pauseWhenFullscreen = value;
                        _dirty = true;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _editable.autostartEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start automatically with the session'),
                    onChanged: (value) {
                      setState(() {
                        _editable.autostartEnabled = value;
                        _dirty = true;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _dirty
                            ? () async {
                                await widget.controller.saveConfig(_editable.toConfig());
                                setState(() {
                                  _dirty = false;
                                });
                              }
                            : null,
                        child: const Text('Save'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await widget.controller.reloadConfig();
                          setState(() {
                            _dirty = false;
                          });
                        },
                        child: const Text('Reload from disk'),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.controller.sortNow(),
                        child: const Text('Sort now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Rules',
              action: FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _editable.rules.add(EditableRule.defaults());
                    _dirty = true;
                  });
                },
                child: const Text('Add rule'),
              ),
              child: Column(
                children: [
                  const Text(
                    'Rules run top to bottom. Use Keep on desktop + Stop processing to pin selected files.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _editable.rules.length; i++) ...[
                    _ruleCard(i),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Recent activity',
              child: SizedBox(
                height: 240,
                child: snapshot.recentEvents.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No events yet.', style: TextStyle(color: Colors.white70)),
                      )
                    : ListView.builder(
                        itemCount: snapshot.recentEvents.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(snapshot.recentEvents[index]),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleCard(int index) {
    final rule = _editable.rules[index];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2026),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Switch(
                value: rule.enabled,
                onChanged: (value) {
                  setState(() {
                    rule.enabled = value;
                    _dirty = true;
                  });
                },
              ),
              Text('Rule ${index + 1}'),
              const SizedBox(width: 8),
              IconButton(
                onPressed: index > 0
                    ? () {
                        setState(() {
                          final tmp = _editable.rules[index - 1];
                          _editable.rules[index - 1] = _editable.rules[index];
                          _editable.rules[index] = tmp;
                          _dirty = true;
                        });
                      }
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                onPressed: index < _editable.rules.length - 1
                    ? () {
                        setState(() {
                          final tmp = _editable.rules[index + 1];
                          _editable.rules[index + 1] = _editable.rules[index];
                          _editable.rules[index] = tmp;
                          _dirty = true;
                        });
                      }
                    : null,
                icon: const Icon(Icons.arrow_downward),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _editable.rules.removeAt(index);
                    _dirty = true;
                  });
                },
                child: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: rule.name,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (value) {
              rule.name = value;
              _markDirty();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: rule.extensionsCsv,
            decoration: const InputDecoration(labelText: 'Extensions (csv)'),
            onChanged: (value) {
              rule.extensionsCsv = value;
              _markDirty();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: rule.fileNamePatternsCsv,
            decoration: const InputDecoration(labelText: 'Include patterns (csv)'),
            onChanged: (value) {
              rule.fileNamePatternsCsv = value;
              _markDirty();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: rule.excludePatternsCsv,
            decoration: const InputDecoration(labelText: 'Exclude patterns (csv)'),
            onChanged: (value) {
              rule.excludePatternsCsv = value;
              _markDirty();
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SortMode>(
            initialValue: rule.mode,
            decoration: const InputDecoration(labelText: 'Action'),
            items: SortMode.values
                .map(
                  (mode) => DropdownMenuItem<SortMode>(
                    value: mode,
                    child: Text(mode.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                rule.mode = value;
                _dirty = true;
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: rule.stopAfterMatch,
            contentPadding: EdgeInsets.zero,
            title: const Text('Stop processing more rules after this match'),
            onChanged: (value) {
              setState(() {
                rule.stopAfterMatch = value;
                _dirty = true;
              });
            },
          ),
          if (rule.mode.needsTarget) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: rule.targetFolder,
                    decoration: const InputDecoration(labelText: 'Target folder'),
                    onChanged: (value) {
                      rule.targetFolder = value;
                      _markDirty();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _pickRuleTarget(index),
                  child: const Text('Browse'),
                ),
              ],
            ),
          ],
          if (rule.mode.needsPattern) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: rule.targetPattern,
              decoration: const InputDecoration(labelText: 'Pattern'),
              onChanged: (value) {
                rule.targetPattern = value;
                _markDirty();
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Tokens: {yyyy} {MM} {dd} {HH} {mm} {ss} {name} {ext}',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.20),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
