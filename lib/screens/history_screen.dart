import 'package:emergency_app/screens/track_rescue.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  String selectedFilter = 'All';
  final List<String> filterOptions = ['All', 'Resolved', 'Pending', 'Active'];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Start animations only if widget is mounted
    if (mounted) {
      _slideController.forward();
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF4CAF50);
      case 'pending':
        return const Color(0xFFFF9800);
      case 'active':
      case 'dispatched':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFFF44336);
    }
  }

  IconData _getReportIcon(String reportType) {
    switch (reportType.toLowerCase()) {
      case 'health care':
      case 'medical':
        return Icons.local_hospital;
      case 'fire & safety':
      case 'fire':
        return Icons.local_fire_department;
      case 'police':
        return Icons.security;
      case 'accident':
        return Icons.car_crash;
      default:
        return Icons.emergency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF001970)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(),
              _buildFilterSection(),
              Expanded(child: _buildHistoryContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
      ),
      child: Container(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(Icons.history, color: Colors.white, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency History',
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Track your emergency reports',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(Icons.filter_list, color: Colors.white, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        height: 60.h,
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filterOptions.length,
          itemBuilder: (context, index) {
            final option = filterOptions[index];
            final isSelected = selectedFilter == option;

            return GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    selectedFilter = option;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.9),
                            ],
                          )
                          : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25.r),
                  border: Border.all(
                    color:
                        isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                          : null,
                ),
                child: Center(
                  child: Text(
                    option,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color:
                          isSelected ? const Color(0xFF1565C0) : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (_auth.currentUser == null) {
      return _buildErrorState('User not authenticated. Please sign in.');
    }

    return Container(
      margin: EdgeInsets.only(top: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
        child: RefreshIndicator(
          color: const Color(0xFF1565C0),
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) setState(() {}); // Trigger rebuild
          },
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('users')
                    .doc(_auth.currentUser!.uid)
                    .collection('emergencyReports')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              if (snapshot.hasError) {
                debugPrint('Firestore error: ${snapshot.error}');
                return _buildErrorState(snapshot.error.toString());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              var reports = snapshot.data!.docs;

              if (selectedFilter != 'All') {
                reports =
                    reports.where((report) {
                      final status = report['status'] as String? ?? 'Unknown';
                      return status.toLowerCase() ==
                          selectedFilter.toLowerCase();
                    }).toList();
              }

              if (reports.isEmpty) {
                return _buildEmptyFilterState();
              }

              return ListView.builder(
                padding: EdgeInsets.all(20.w),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  // Delay animation for each item to prevent overload
                  return FutureBuilder(
                    future: Future.delayed(Duration(milliseconds: index * 100)),
                    builder:
                        (context, _) =>
                            _buildPremiumReportCard(reports[index], index),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumReportCard(QueryDocumentSnapshot report, int index) {
    final data = report.data() as Map<String, dynamic>? ?? {};
    final reportType = data['reportType'] as String? ?? 'Emergency Report';
    final description =
        data['description'] as String? ?? 'No description available';
    final status = data['status'] as String? ?? 'Unknown';
    final createdAt = data['createdAt'] as Timestamp?;
    final formattedDate =
        createdAt != null
            ? DateFormat('MMM dd, yyyy • HH:mm').format(createdAt.toDate())
            : 'Unknown date';
    final locationData = data['location'] as Map<String, dynamic>?;
    final location =
        locationData != null && locationData['address'] is String
            ? locationData['address'] as String
            : 'Location unavailable';

    // Adjust interval to ensure end <= 1.0
    double begin = (0.1 * index).clamp(0.0, 0.7);
    double end = (begin + 0.3).clamp(0.0, 1.0);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _slideController,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: () {
              if (status.toLowerCase() == 'active') {
                final latitude =
                    (locationData?['latitude'] as num?)?.toDouble();
                final longitude =
                    (locationData?['longitude'] as num?)?.toDouble();

                if (latitude != null && longitude != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => TrackRescuerScreen(
                            reportId: report.id,
                            emergencyLat: latitude,
                            emergencyLon: longitude,
                          ),
                    ),
                  );
                } else {
                  debugPrint(
                    'Active report tapped, but missing location data for tracking: ${report.id}',
                  );
                }
              } else {
                debugPrint(
                  'Tapped $status report: ${report.id}. No tracking available for this status.',
                );
              }
            },
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(status).withOpacity(0.2),
                              _getStatusColor(status).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _getReportIcon(reportType),
                          color: _getStatusColor(status),
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reportType,
                              style: GoogleFonts.poppins(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(status),
                              _getStatusColor(status).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(status).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.grey.shade600,
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.description,
                              color: Colors.grey.shade600,
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                description,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade400,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1565C0).withOpacity(0.1),
                  const Color(0xFF1565C0).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: const Color(0xFF1565C0),
              strokeWidth: 3.w,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Loading your history...',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.1),
                  Colors.red.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 48.sp,
              color: Colors.red.shade400,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Unable to Load History',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1565C0).withOpacity(0.1),
                  const Color(0xFF1565C0).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off,
              size: 48.sp,
              color: const Color(0xFF1565C0),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No Emergency Reports Yet',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Your emergency reports will appear here.\nStay safe and prepared!',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.orange.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.filter_list_off,
              size: 48.sp,
              color: Colors.orange.shade400,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No $selectedFilter Reports',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Try selecting a different filter\nto view other reports',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
