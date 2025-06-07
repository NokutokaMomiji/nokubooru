import 'package:flutter/material.dart';
import 'package:nokubooru/themes.dart';

class ThemedSwitch extends StatefulWidget {
    final bool value;
    final void Function(bool)? onChanged;

    const ThemedSwitch({required this.value, required this.onChanged, super.key});

    @override
    State<ThemedSwitch> createState() => _ThemedSwitchState();
}

class _ThemedSwitchState extends State<ThemedSwitch> {
    bool active = false;
    
    @override
    void initState() {
        super.initState();

        active = widget.value;
    }

    @override
    Widget build(BuildContext context) {
        final onChanged = widget.onChanged;
        
        return Switch(
            inactiveThumbColor: Themes.white,
            activeColor: Themes.accent,
            value: active, 
            onChanged: (value) {
                if (onChanged != null) {
                    onChanged(value);
                }

                setState((){
                    active = !active;
                });
            }
        );
    }
}

class ThemedOutlinedButton extends StatelessWidget {
    final VoidCallback? onPressed;
    final String label;
    final IconData icon;

    const ThemedOutlinedButton({required this.onPressed, required this.label, required this.icon, super.key});

    @override
    Widget build(BuildContext context) => OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                side: BorderSide(
                    width: 2.0,
                    color: (onPressed != null) ? Themes.accent : Theme.of(context).disabledColor
                )
            ),
            onPressed: onPressed, 
            label: Text(
                label,
                style: TextStyle(
                    color: (onPressed != null) ? Themes.accent : Theme.of(context).disabledColor
                ),
            ),
            icon: Icon(
                icon, 
                color: (onPressed != null) ? Themes.accent : Theme.of(context).disabledColor
            ),
        );
}