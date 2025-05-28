import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.blue[400],
        elevation: 0,
        title: Text(
          'Emergency Report History',
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              _auth.currentUser != null
                  ? _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .collection('emergencyReports')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                  : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.blue[400],
                  strokeWidth: 3.w,
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 50.sp,
                      color: Colors.red[400],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Error loading history: ${snapshot.error}',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 60.sp,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No emergency reports found.',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Your emergency reports will appear here.',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final reports = snapshot.data!.docs;

            return ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final reportType = report['reportType'] ?? 'Unknown';
                final description = report['description'] ?? 'No description';
                final status = report['status'] ?? 'Unknown';
                final createdAt = (report['createdAt'] as Timestamp?)?.toDate();
                final formattedDate =
                    createdAt != null
                        ? DateFormat('MMM dd, yyyy - HH:mm').format(createdAt)
                        : 'Unknown date';
                final location =
                    report['location'] != null
                        ? (report['location'] as Map)['address'] ??
                            'Unknown location'
                        : 'Unknown location';

                return GestureDetector(
                  onTap: () {
                    // Placeholder for future report details screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tapped on $reportType report')),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    reportType,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        status == 'Resolved'
                                            ? Colors.green[100]
                                            : status == 'Pending'
                                            ? Colors.orange[100]
                                            : Colors.red[100],
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                      color:
                                          status == 'Resolved'
                                              ? Colors.green[300]!
                                              : status == 'Pending'
                                              ? Colors.orange[300]!
                                              : Colors.red[300]!,
                                      width: 1.w,
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          status == 'Resolved'
                                              ? Colors.green[800]
                                              : status == 'Pending'
                                              ? Colors.orange[800]
                                              : Colors.red[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_pin,
                                  size: 16.sp,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              description,
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14.sp,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Reported on: $formattedDate',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
