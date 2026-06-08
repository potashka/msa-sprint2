package com.hotelio.monolith.grpc;

import com.google.protobuf.CodedInputStream;
import com.google.protobuf.CodedOutputStream;
import com.hotelio.monolith.entity.Booking;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.MethodDescriptor;
import io.grpc.StatusRuntimeException;
import io.grpc.stub.ClientCalls;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.time.Instant;

@Component
public class GrpcBookingClient {
    private final ManagedChannel channel;
    private final MethodDescriptor<BookingRequest, BookingResponse> createBookingMethod;

    public GrpcBookingClient(
            @Value("${BOOKING_SERVICE_EXTERNAL_HOST:booking-service}") String host,
            @Value("${BOOKING_SERVICE_EXTERNAL_PORT:9090}") int port
    ) {
        this.channel = ManagedChannelBuilder.forAddress(host, port).usePlaintext().build();
        this.createBookingMethod = MethodDescriptor.<BookingRequest, BookingResponse>newBuilder()
                .setType(MethodDescriptor.MethodType.UNARY)
                .setFullMethodName(MethodDescriptor.generateFullMethodName("booking.BookingService", "CreateBooking"))
                .setRequestMarshaller(new BookingRequestMarshaller())
                .setResponseMarshaller(new BookingResponseMarshaller())
                .build();
    }

    public Booking createBooking(String userId, String hotelId, String promoCode) {
        try {
            BookingResponse response = ClientCalls.blockingUnaryCall(
                    channel,
                    createBookingMethod,
                    io.grpc.CallOptions.DEFAULT,
                    new BookingRequest(userId, hotelId, promoCode)
            );

            Booking booking = new Booking();
            booking.setId(Long.valueOf(response.id));
            booking.setUserId(response.userId);
            booking.setHotelId(response.hotelId);
            booking.setPromoCode(response.promoCode == null || response.promoCode.isBlank() ? null : response.promoCode);
            booking.setDiscountPercent(response.discountPercent);
            booking.setPrice(response.price);
            booking.setCreatedAt(Instant.parse(response.createdAt));
            return booking;
        } catch (StatusRuntimeException e) {
            throw new IllegalArgumentException(e.getStatus().getDescription(), e);
        }
    }

    private record BookingRequest(String userId, String hotelId, String promoCode) {
    }

    private record BookingResponse(
            String id,
            String userId,
            String hotelId,
            String promoCode,
            double discountPercent,
            double price,
            String createdAt
    ) {
    }

    private static class BookingRequestMarshaller implements MethodDescriptor.Marshaller<BookingRequest> {
        @Override
        public InputStream stream(BookingRequest value) {
            try {
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                CodedOutputStream coded = CodedOutputStream.newInstance(out);
                writeString(coded, 1, value.userId);
                writeString(coded, 2, value.hotelId);
                writeString(coded, 3, value.promoCode);
                coded.flush();
                return new ByteArrayInputStream(out.toByteArray());
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }

        @Override
        public BookingRequest parse(InputStream stream) {
            throw new UnsupportedOperationException("Client does not parse booking requests");
        }
    }

    private static class BookingResponseMarshaller implements MethodDescriptor.Marshaller<BookingResponse> {
        @Override
        public InputStream stream(BookingResponse value) {
            throw new UnsupportedOperationException("Client does not stream booking responses");
        }

        @Override
        public BookingResponse parse(InputStream stream) {
            try {
                CodedInputStream input = CodedInputStream.newInstance(stream);
                String id = "";
                String userId = "";
                String hotelId = "";
                String promoCode = "";
                double discountPercent = 0.0;
                double price = 0.0;
                String createdAt = "";

                int tag;
                while ((tag = input.readTag()) != 0) {
                    int field = tag >>> 3;
                    switch (field) {
                        case 1 -> id = input.readStringRequireUtf8();
                        case 2 -> userId = input.readStringRequireUtf8();
                        case 3 -> hotelId = input.readStringRequireUtf8();
                        case 4 -> promoCode = input.readStringRequireUtf8();
                        case 5 -> discountPercent = input.readDouble();
                        case 6 -> price = input.readDouble();
                        case 7 -> createdAt = input.readStringRequireUtf8();
                        default -> input.skipField(tag);
                    }
                }
                return new BookingResponse(id, userId, hotelId, promoCode, discountPercent, price, createdAt);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }
    }

    private static void writeString(CodedOutputStream coded, int field, String value) throws java.io.IOException {
        if (value != null && !value.isBlank()) {
            coded.writeString(field, value);
        }
    }
}
