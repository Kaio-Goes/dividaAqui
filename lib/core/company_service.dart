import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:divida_aqui/core/company_model.dart';

class CompanyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('companies');

  Stream<List<CompanyModel>> streamCompanies() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => CompanyModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<CompanyModel>> fetchCompanies() async {
    final snap = await _col.orderBy('name').get();
    return snap.docs.map((d) => CompanyModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> addCompany(CompanyModel company) async {
    await _col.add(company.toMap());
  }

  Future<void> updateCompany(CompanyModel company) async {
    await _col.doc(company.id).update(company.toMap());
  }

  Future<void> deleteCompany(String id) async {
    await _col.doc(id).delete();
  }
}
