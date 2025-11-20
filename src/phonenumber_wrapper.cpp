// C wrapper for Google's libphonenumber C++ library
// Provides a C-compatible FFI interface for Zig bindings

#include <phonenumbers/phonenumberutil.h>
#include <phonenumbers/phonenumber.pb.h>
#include <string>
#include <cstring>

extern "C" {

using namespace i18n::phonenumbers;

// Get singleton instance of PhoneNumberUtil
PhoneNumberUtil* phoneutil_get_instance() {
    return PhoneNumberUtil::GetInstance();
}

// Parse a phone number string
bool phoneutil_parse(
    PhoneNumberUtil* util,
    const char* number_to_parse,
    const char* default_region,
    PhoneNumber** phone_number_out,
    int* error_type_out
) {
    PhoneNumber* phone_number = new PhoneNumber();
    PhoneNumberUtil::ErrorType error;
    
    bool success = (util->Parse(
        std::string(number_to_parse),
        std::string(default_region),
        phone_number
    ) == PhoneNumberUtil::NO_PARSING_ERROR);
    
    if (success) {
        *phone_number_out = phone_number;
        *error_type_out = 0;
        return true;
    } else {
        delete phone_number;
        *phone_number_out = nullptr;
        *error_type_out = static_cast<int>(error);
        return false;
    }
}

// Check if a number is valid
bool phoneutil_is_valid_number(
    PhoneNumberUtil* util,
    PhoneNumber* number
) {
    return util->IsValidNumber(*number);
}

// Check if a number is possible
bool phoneutil_is_possible_number(
    PhoneNumberUtil* util,
    PhoneNumber* number
) {
    return util->IsPossibleNumber(*number);
}

// Check if a number is possible with detailed reason
int phoneutil_is_possible_number_with_reason(
    PhoneNumberUtil* util,
    PhoneNumber* number
) {
    return static_cast<int>(util->IsPossibleNumberWithReason(*number));
}

// Get the type of phone number
int phoneutil_get_number_type(
    PhoneNumberUtil* util,
    PhoneNumber* number
) {
    return static_cast<int>(util->GetNumberType(*number));
}

// Format a phone number
void phoneutil_format_number(
    PhoneNumberUtil* util,
    PhoneNumber* number,
    int format,
    char** formatted_out,
    size_t* formatted_len_out
) {
    std::string formatted;
    PhoneNumberUtil::PhoneNumberFormat fmt = 
        static_cast<PhoneNumberUtil::PhoneNumberFormat>(format);
    
    util->Format(*number, fmt, &formatted);
    
    *formatted_len_out = formatted.length();
    *formatted_out = static_cast<char*>(malloc(formatted.length() + 1));
    std::strcpy(*formatted_out, formatted.c_str());
}

// Get region code for a number
void phoneutil_get_region_code(
    PhoneNumberUtil* util,
    PhoneNumber* number,
    char** region_out,
    size_t* region_len_out
) {
    std::string region;
    util->GetRegionCodeForNumber(*number, &region);
    
    *region_len_out = region.length();
    *region_out = static_cast<char*>(malloc(region.length() + 1));
    std::strcpy(*region_out, region.c_str());
}

// Get country code from a number
int phoneutil_get_country_code(PhoneNumber* number) {
    return number->country_code();
}

// Get national number
uint64_t phoneutil_get_national_number(PhoneNumber* number) {
    return number->national_number();
}

// Compare two phone numbers
int phoneutil_is_number_match(
    PhoneNumberUtil* util,
    PhoneNumber* number1,
    PhoneNumber* number2
) {
    return static_cast<int>(util->IsNumberMatch(*number1, *number2));
}

// Free a phone number object
void phoneutil_free_number(PhoneNumber* number) {
    delete number;
}

// Free a C string allocated by wrapper
void phoneutil_free_string(char* str) {
    free(str);
}

} // extern "C"
