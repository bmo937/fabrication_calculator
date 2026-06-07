// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_calculator.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ManagedCalculatorAdapter extends TypeAdapter<ManagedCalculator> {
  @override
  final int typeId = 3;

  @override
  ManagedCalculator read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ManagedCalculator(
      id: fields[0] as String,
      groupId: fields[1] as String,
      name: fields[2] as String,
      calculatorType: fields[3] as String,
      inputLabel: fields[4] as String,
      outputLabel: fields[5] as String,
      formulaExpression: fields[6] as String?,
      lookupEntriesJson: fields[7] as String?,
      sortOrder: (fields[8] as int?) ?? 0,
      description: (fields[9] as String?) ?? '',
      isDraft: (fields[10] as bool?) ?? false,
      sandboxTestPassed: (fields[11] as bool?) ?? false,
      lastSandboxTestAt: fields[12] as DateTime?,
      publishedAt: fields[13] as DateTime?,
      codeBody: (fields[14] as String?) ?? '',
      inputDefinitionsJson: (fields[15] as String?) ?? '',
      outputDefinitionsJson: (fields[16] as String?) ?? '',
      sandboxLastError: (fields[17] as String?) ?? '',
      codeLanguage: (fields[18] as String?) ?? 'math',
      iconKey: (fields[19] as String?) ?? 'function',
    );
  }

  @override
  void write(BinaryWriter writer, ManagedCalculator obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.calculatorType)
      ..writeByte(4)
      ..write(obj.inputLabel)
      ..writeByte(5)
      ..write(obj.outputLabel)
      ..writeByte(6)
      ..write(obj.formulaExpression)
      ..writeByte(7)
      ..write(obj.lookupEntriesJson)
      ..writeByte(8)
      ..write(obj.sortOrder)
      ..writeByte(9)
      ..write(obj.description)
      ..writeByte(10)
      ..write(obj.isDraft)
      ..writeByte(11)
      ..write(obj.sandboxTestPassed)
      ..writeByte(12)
      ..write(obj.lastSandboxTestAt)
      ..writeByte(13)
      ..write(obj.publishedAt)
      ..writeByte(14)
      ..write(obj.codeBody)
      ..writeByte(15)
      ..write(obj.inputDefinitionsJson)
      ..writeByte(16)
      ..write(obj.outputDefinitionsJson)
      ..writeByte(17)
      ..write(obj.sandboxLastError)
      ..writeByte(18)
      ..write(obj.codeLanguage)
      ..writeByte(19)
      ..write(obj.iconKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ManagedCalculatorAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
